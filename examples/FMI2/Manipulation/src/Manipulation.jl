#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

using FMIExport: fmi2SetFctGetReal, fmi2CreateEmbedded
using FMIExport.FMIBase.FMICore: fmi2Real, fmi2Component, fmi2StatusOK, fmi2ValueReference
using FMIExport.FMIBase.FMICore:
    fmi2CausalityParameter, fmi2VariabilityTunable, fmi2InitialExact
using FMIImport: loadFMU
import FMIExport

originalGetReal = nothing # function pointer to the original fmi2GetReal c-function

# custom function for fmi2GetReal!(fmi2Component, Union{Array{fmi2ValueReference}, Ptr{fmi2ValueReference}}, Csize_t, value::Union{Array{fmi2Real}, Ptr{fmi2Real}}::fmi2Status
# for information on how the FMI2-functions are structured, have a look inside FMICore.jl/src/FMI2_c.jl or the FMI2.0.3-specification on fmi-standard.org
function myGetReal!(
    c::fmi2Component,
    vr::Union{Array{fmi2ValueReference},Ptr{fmi2ValueReference}},
    nvr::Csize_t,
    value::Union{Array{fmi2Real},Ptr{fmi2Real}},
)
    global originalGetReal

    # first, we do what the original function does
    status = FMIExport.FMIBase.FMICore.fmi2GetReal!(originalGetReal, c, vr, nvr, value)

    # if we have a pointer to an array, we must interprete it as array to access elements
    if isa(value, Ptr{fmi2Real})
        value = unsafe_wrap(Array{fmi2Real}, value, nvr, own = false)
    end
    if isa(vr, Ptr{fmi2ValueReference})
        vr = unsafe_wrap(Array{fmi2ValueReference}, vr, nvr, own = false)
    end

    # now, we add noise (just for fun!)
    for i = 1:nvr
        if vr[i] == 335544320 # value reference for "positionSensor.s"
            value[i] += (-0.5 + rand()) * 0.25
        end
    end

    # ... and we return the original status
    return status
end

# this function is called, as soon as the DLL is loaded and Julia is initialized 
# must return a FMU2-instance to work with
FMIBUILD_CONSTRUCTOR = function (resPath)
    global originalGetReal

    # loads an existing FMU inside the FMU
    fmu = loadFMU(joinpath(resPath, "SpringDamperPendulum1D.fmu"))

    # create a FMU that embedds the existing FMU
    fmu = fmi2CreateEmbedded(fmu)

    fmu.modelDescription.modelName = "Manipulation"
    fmu.modelDescription.modelExchange.modelIdentifier = "Manipulation"
    fmu.modelDescription.coSimulation = nothing

    # deactivate special features, because they are not implemented yet
    fmu.modelDescription.modelExchange.canGetAndSetFMUstate = false
    fmu.modelDescription.modelExchange.canSerializeFMUstate = false
    fmu.modelDescription.modelExchange.providesDirectionalDerivative = false

    # save, where the original `fmi2GetReal` function was stored, so we can access it in our new function
    originalGetReal = fmu.cGetReal

    # now we overwrite the original function
    fmi2SetFctGetReal(fmu, myGetReal!)

    return fmu
end

### FMIBUILD_NO_EXPORT_BEGIN ###
# The line above is a start-marker for excluded code for the FMU compilation process!

import FMIZoo
sourceFMU = FMIZoo.get_model_filename("SpringDamperPendulum1D", "Dymola", "2022x")
fmu = FMIBUILD_CONSTRUCTOR(dirname(sourceFMU))

# first, we try to simulate the FMU before ExternalFMIExportTesting
# this is not required for export but a good idea anyway: 
# the export takes a long time and exporting a possibly broken FMU does not help anyone
using FMI, DifferentialEquations
fmu.executionConfig.loggingOn = true
solution =
    simulateME(fmu, (0.0, 5.0); dtmax = 0.1, recordValues = [fmi2ValueReference(335544320)])
# using Plots
# plot(solution)

tmpDir = mktempdir(; prefix = "fmibuildjl_test_", cleanup = false)
@info "Saving example files at: $(tmpDir)"
fmu_save_path = joinpath(tmpDir, "Manipulation.fmu")

import FMIBuild: saveFMU        # <= this must be excluded during export, because FMIBuild cannot execute itself (but it is able to build)
saveFMU(fmu, fmu_save_path; resources = Dict(sourceFMU => "SpringDamperPendulum1D.fmu"))    # <= this must be excluded during export, because fmi2Save would start an infinte build loop with itself 

# The following line is a end-marker for excluded code for the FMU compilation process!
### FMIBUILD_NO_EXPORT_END ###
