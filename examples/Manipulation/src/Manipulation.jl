#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

# the FMI version of the exported FMU (2 or 3)
const FMI_VERSION = 2

using FMIExport: createFMU2Embedded, createFMU3Embedded, addRealOutput
using FMIExport.FMIBase: fmiValueReference
using FMIExport.FMIBase.FMICore: fmi2Real, fmi2Component, fmi3Float64, fmi3Instance
using FMIImport: loadFMU, unloadFMU
import FMIExport

# types and functions that depend on the FMI version
const fmiReal = FMI_VERSION == 2 ? fmi2Real : fmi3Float64
const fmiComponent = FMI_VERSION == 2 ? fmi2Component : fmi3Instance
const createFMUEmbedded = FMI_VERSION == 2 ? createFMU2Embedded : createFMU3Embedded
const setFctGetReal =
    FMI_VERSION == 2 ? FMIExport.setFctGetReal : FMIExport.setFctGetFloat64
# the FMI 3 getter has an additional argument for the number of values (equals `nvr` for scalar variables)
fmiGetReal!(cfunc, c, vr, nvr, value) =
    FMI_VERSION == 2 ? FMIExport.FMICore.fmi2GetReal!(cfunc, c, vr, nvr, value) :
    FMIExport.FMICore.fmi3GetFloat64!(cfunc, c, vr, nvr, value, nvr)
# field names that depend on the FMI version
const cGetReal = FMI_VERSION == 2 ? :cGetReal : :cGetFloat64
const canGetAndSetFMUState =
    FMI_VERSION == 2 ? :canGetAndSetFMUstate : :canGetAndSetFMUState
const canSerializeFMUState =
    FMI_VERSION == 2 ? :canSerializeFMUstate : :canSerializeFMUState
const providesDirectionalDerivatives =
    FMI_VERSION == 2 ? :providesDirectionalDerivative : :providesDirectionalDerivatives

# value reference of the additional output, it must not be used by the embedded FMU
const NOISY_POSITION_VR = fmiValueReference(1)

originalGetReal = nothing # function pointer to the original fmi2GetReal / fmi3GetFloat64 c-function
positionVR = nothing # value reference of the mass position in the embedded FMU

# custom function for fmi2GetReal!(fmi2Component, Union{Array{fmi2ValueReference}, Ptr{fmi2ValueReference}}, Csize_t, value::Union{Array{fmi2Real}, Ptr{fmi2Real}})::fmi2Status,
# the FMI 3 counterpart fmi3GetFloat64! has the additional argument `nValues` (number of values)
# for information on how the FMI-functions are structured, have a look inside FMICore.jl/src/FMI2/cfunc.jl (and FMI3/cfunc.jl) or the FMI-specifications on fmi-standard.org
function myGetReal!(
    c::fmiComponent,
    vr::Union{Array{fmiValueReference},Ptr{fmiValueReference}},
    nvr::Csize_t,
    value::Union{Array{fmiReal},Ptr{fmiReal}},
    nValues::Csize_t...,
)
    global originalGetReal, positionVR

    # if we have a pointer to an array, we must interprete it as array to access elements
    if isa(value, Ptr{fmiReal})
        value = unsafe_wrap(Array{fmiReal}, value, nvr, own = false)
    end
    if isa(vr, Ptr{fmiValueReference})
        vr = unsafe_wrap(Array{fmiValueReference}, vr, nvr, own = false)
    end

    # first, we do what the original function does,
    # the embedded FMU doesn't know the additional output, so we ask for the position instead
    vrEmbedded = fmiValueReference[(v == NOISY_POSITION_VR ? positionVR : v) for v in vr]
    status = fmiGetReal!(originalGetReal, c, vrEmbedded, nvr, value)

    # now, we add noise to the additional output (just for fun!)
    for i = 1:nvr
        if vr[i] == NOISY_POSITION_VR
            value[i] += (-1.0 + 2.0 * rand()) * 1e-2
        end
    end

    # ... and we return the original status
    return status
end

# this function is called, as soon as the DLL is loaded and Julia is initialized
# must return a FMU2- or FMU3-instance (depending on `FMI_VERSION`) to work with
FMIBUILD_CONSTRUCTOR = function (resPath)
    global originalGetReal, positionVR

    # loads an existing FMU inside the FMU
    fmu = loadFMU(joinpath(resPath, "SpringPendulum1D.fmu"))

    # create a FMU that embedds the existing FMU
    fmu = createFMUEmbedded(fmu)

    fmu.modelDescription.modelName = "Manipulation"
    fmu.modelDescription.modelExchange.modelIdentifier = "Manipulation"
    fmu.modelDescription.coSimulation = nothing # remove co simulation functionality

    # deactivate special features, because they are not implemented yet
    setproperty!(fmu.modelDescription.modelExchange, canGetAndSetFMUState, false)
    setproperty!(fmu.modelDescription.modelExchange, canSerializeFMUState, false)
    setproperty!(fmu.modelDescription.modelExchange, providesDirectionalDerivatives, false)

    # add an output for the position of the mass (with noise)
    positionVR = fmu.modelDescription.stringValueReferences["mass.s"]
    addRealOutput(
        fmu,
        "mass.s_noisy";
        valueReference = NOISY_POSITION_VR,
        description = "Absolute position of the mass with (artificial) noise",
    )

    # save, where the original `fmi2GetReal` / `fmi3GetFloat64` function was stored, so we can access it in our new function
    originalGetReal = getproperty(fmu, cGetReal)

    # now we overwrite the original function
    setFctGetReal(fmu, myGetReal!)

    return fmu
end

### FMIBUILD_NO_EXPORT_BEGIN ###
# The line above is a start-marker for excluded code for the FMU compilation process!

import FMIZoo
sourceFMU =
    FMIZoo.get_model_filename("SpringPendulum1D", "Dymola", "2023x", "$(FMI_VERSION).0")
fmu = FMIBUILD_CONSTRUCTOR(dirname(sourceFMU))

# first, we try to simulate the FMU before ExternalFMIExportTesting
# this is not required for export but a good idea anyway:
# the export takes a long time and exporting a possibly broken FMU does not help anyone

# using FMI, DifferentialEquations
# fmu.executionConfig.loggingOn = true
# solution = simulateME(
#     fmu,
#     (0.0, 5.0);
#     dtmax = 0.1,
#     saveat = 0.0:0.01:5.0,
#     recordValues = ["mass.s", "mass.s_noisy"],
# )

# using Plots
# plot(solution)

tmpDir = mktempdir(; prefix = "fmibuildjl_test_", cleanup = false)
@info "Saving example files at: $(tmpDir)"
fmu_save_path = joinpath(tmpDir, "Manipulation.fmu")

# this must be excluded during export -done by FMIBUILD_NO_EXPORT marker-, because FMIBuild cannot execute itself (but it is able to build)
import FMIBuild: saveFMU
# this must be excluded during export -done by FMIBUILD_NO_EXPORT marker-, because saveFMU would start an infinite build loop with itself
saveFMU(
    fmu,
    fmu_save_path;
    resources = Dict(sourceFMU => "SpringPendulum1D.fmu"),
    debug = true, # debug=true allows debug messages, but is slow during execution!
)
unloadFMU(fmu)

# The following line is a end-marker for excluded code for the FMU compilation process!
### FMIBUILD_NO_EXPORT_END ###
