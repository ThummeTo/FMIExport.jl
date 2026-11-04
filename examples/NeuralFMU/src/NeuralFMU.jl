#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

# the FMI version of the exported FMU (2 or 3)
const FMI_VERSION = 3

using FMIExport: Dense, Chain
using FMIExport: setFctGetDerivatives, setFctGetReal, setFctSetReal
using FMIExport: setFctSetTime, setFctSetContinuousStates
using FMIExport: addRealParameter
using FMIExport.FMIBase: logError, logWarning
using FMIImport: loadFMU, unloadFMU
import FMIExport

# version-independent names (e.g. `fmiReal` or `createFMUEmbedded`) for the FMI version
const FMISymbols = FMI_VERSION == 2 ? FMIExport.FMI2Symbols : FMIExport.FMI3Symbols
using .FMISymbols

fmu = nothing

originalGetDerivatives = nothing # function pointer to the original fmi2GetDerivatives / fmi3GetContinuousStateDerivatives c-function
originalGetReal = nothing # function pointer to the original fmi2GetReal / fmi3GetFloat64 c-function
originalSetReal = nothing # function pointer to the original fmi2SetReal / fmi3SetFloat64 c-function
originalSetTime = nothing
originalSetContinuousStates = nothing

model = Chain(Dense{Float64}(2, 2, identity), Dense{Float64}(2, 2, identity))
model[1].W[1, 1] = 1.0
model[1].W[2, 2] = 0.5
model[2].W[1, 1] = 1.0
model[2].W[2, 2] = 1.0

function getParameter(vrs)

    values = []

    for vr in vrs
        for l = 1:length(model)
            layer = model[l]

            if isa(layer, Dense)
                for i = 1:size(layer.W)[1]
                    for j = 1:size(layer.W)[2]

                        vr -= 1
                        if vr == 0
                            push!(values, layer.W[i, j])
                        end
                    end

                    vr -= 1
                    if vr == 0
                        push!(values, layer.b[i])
                    end
                end
            end
        end
    end

    return values
end

function setParameter(vrs, values)

    for v = 1:length(vrs)
        vr = vrs[v]
        value = values[v]

        for l = 1:length(model)
            layer = model[l]

            for i = 1:size(layer.W)[1]
                for j = 1:size(layer.W)[2]

                    vr -= 1
                    if vr == 0
                        layer.W[i, j] = value
                        break
                    end
                end

                vr -= 1
                if vr == 0
                    layer.b[i] = value
                    break
                end
            end
        end
    end

    return nothing
end

ANN_PARAMETERS = []

# sort VRs/VALUEs into (FMU values, derivatives, ANN parameters)
function sortVRs(fmu, vrs, values)
    global ANN_PARAMETERS

    valuesFMU = Array{fmiReal,1}()
    vrsFMU = Array{fmiValueReference,1}()
    idxFMU = Array{Integer,1}()

    valuesDER = Array{fmiReal,1}()
    vrsDER = Array{fmiValueReference,1}()
    idxDER = Array{Integer,1}()

    valuesANN = Array{fmiReal,1}()
    vrsANN = Array{fmiValueReference,1}()
    idxANN = Array{Integer,1}()

    for i = 1:length(vrs)
        vr = vrs[i]
        value = values[i]

        if vr ∈ ANN_PARAMETERS
            push!(valuesANN, value)
            push!(vrsANN, vr)
            push!(idxANN, i)

        elseif vr ∈ fmu.modelDescription.derivativeValueReferences
            push!(valuesDER, value)
            push!(vrsDER, vr)
            push!(idxDER, i)

        else
            push!(valuesFMU, value)
            push!(vrsFMU, vr)
            push!(idxFMU, i)
        end
    end

    return (valuesFMU, vrsFMU, idxFMU, valuesDER, vrsDER, idxDER, valuesANN, vrsANN, idxANN)
end

global DERIVATIVES_VALID = false # whether derivative values are still up to date (or need recompute)
global DERIVATIVES = Array{fmiReal}(undef, 2)
function updateDerivatives(_component::fmiComponent, ndx::Csize_t)

    global DERIVATIVES_VALID, DERIVATIVES
    global originalGetDerivatives

    status = fmiStatusOK

    if !DERIVATIVES_VALID
        # first, we do what the original function does
        status = fmiGetDerivatives!(originalGetDerivatives, _component, DERIVATIVES, ndx)

        if status != fmiStatusOK
            logError(
                FMIExport.dereferenceInstance(_component),
                "Getting the derivatives failed!",
            )
            return fmiStatusError
        end

        tmp = model(DERIVATIVES)
        DERIVATIVES[:] = tmp[:]
        DERIVATIVES_VALID = true
    end

    return status
end

# custom function for fmi2GetDerivatives!(fmi2Component, Union{AbstractArray{fmi2Real}, Ptr{fmi2Real}}, Csize_t)::fmi2Status (fmi3GetContinuousStateDerivatives! in FMI 3)
# for information on how the FMI-functions are structured, have a look inside FMICore.jl/src/FMI2/cfunc.jl (and FMI3/cfunc.jl) or the FMI-specifications on fmi-standard.org
function myGetDerivatives!(
    _component::fmiComponent,
    derivatives::Union{AbstractArray{fmiReal},Ptr{fmiReal}},
    ndx::Csize_t,
)

    global DERIVATIVES
    status = updateDerivatives(_component, ndx)

    # if we have a pointer to an array, we must interprete it as array to access elements
    if isa(derivatives, Ptr{fmiReal})
        derivatives = unsafe_wrap(Array{fmiReal}, derivatives, ndx, own = false)
    end

    derivatives[:] = DERIVATIVES[:]

    # ... and we return the original status
    return status
end

# custom function for fmi2GetReal!(fmi2Component, Union{AbstractArray{fmi2ValueReference}, Ptr{fmi2ValueReference}}, Csize_t, value::Union{AbstractArray{fmi2Real}, Ptr{fmi2Real}})::fmi2Status,
# the FMI 3 counterpart fmi3GetFloat64! has the additional argument `nValues` (number of values)
function myGetReal!(
    _component::fmiComponent,
    vr::Union{AbstractArray{fmiValueReference},Ptr{fmiValueReference}},
    nvr::Csize_t,
    value::Union{AbstractArray{fmiReal},Ptr{fmiReal}},
    nValues::Csize_t...,
)
    global originalGetReal, fmu
    global DERIVATIVES

    # if we have a pointer to an array, we must interprete it as array to access elements
    if isa(value, Ptr{fmiReal})
        value = unsafe_wrap(Array{fmiReal}, value, nvr, own = false)
    end

    if isa(vr, Ptr{fmiValueReference})
        vr = unsafe_wrap(Array{fmiValueReference}, vr, nvr, own = false)
    end

    valuesFMU, vrsFMU, idxFMU, valuesDER, vrsDER, idxDER, valuesANN, vrsANN, idxANN =
        sortVRs(fmu, vr, value)

    ret_status = fmiStatusOK

    if length(valuesANN) > 0
        value[idxANN] = getParameter(vrsANN)
    end

    if length(valuesDER) > 0

        ndx = Csize_t(length(fmu.modelDescription.derivativeValueReferences))
        updateDerivatives(_component, ndx)

        for i = 1:length(valuesDER)

            idDER = idxDER[i]
            vrDER = vrsDER[i]

            dind = 0

            for j = 1:ndx
                if vrDER == fmu.modelDescription.derivativeValueReferences[j]
                    dind = j
                    break
                end
            end

            if dind == 0
                logError(
                    FMIExport.dereferenceInstance(_component),
                    "Can not find value reference in derivatives for `$(vr[idDER])`.",
                )
                return fmiStatusError
            end

            value[idDER] = DERIVATIVES[dind]
        end
    end

    len_valuesFMU = Csize_t(length(valuesFMU))
    if len_valuesFMU > 0
        status = fmiGetReal!(originalGetReal, _component, vrsFMU, len_valuesFMU, valuesFMU)
        ret_status = max(ret_status, status)

        value[idxFMU] = valuesFMU[:]
    end

    # ... and we return the original status
    return ret_status
end

# custom function for fmi2SetReal / fmi3SetFloat64 (with the additional argument `nValues` in FMI 3)
function mySetReal(
    _component::fmiComponent,
    vr::Union{AbstractArray{fmiValueReference},Ptr{fmiValueReference}},
    nvr::Csize_t,
    value::Union{AbstractArray{fmiReal},Ptr{fmiReal}},
    nValues::Csize_t...,
)
    global originalSetReal
    global DERIVATIVES_VALID

    DERIVATIVES_VALID = false # invalidate derivatives

    # if we have a pointer to an array, we must interprete it as array to access elements
    if isa(value, Ptr{fmiReal})
        value = unsafe_wrap(Array{fmiReal}, value, nvr, own = false)
    end

    if isa(vr, Ptr{fmiValueReference})
        vr = unsafe_wrap(Array{fmiValueReference}, vr, nvr, own = false)
    end

    valuesFMU, vrsFMU, idxFMU, valuesDER, vrsDER, idxDER, valuesANN, vrsANN, idxANN =
        sortVRs(fmu, vr, value)

    ret_status = fmiStatusOK

    if length(valuesANN) > 0
        setParameter(vrsANN, valuesANN)
    end

    len_valuesFMU = Csize_t(length(valuesFMU))
    if len_valuesFMU > 0
        status = fmiSetReal(originalSetReal, _component, vrsFMU, len_valuesFMU, valuesFMU)
        ret_status = max(ret_status, status)
    end

    len_valuesDER = Csize_t(length(valuesDER))
    if len_valuesDER > 0
        # ToDo: Here, a reverse propagation (by optimization) through the ANN is necessary!
        logWarning(
            FMIExport.dereferenceInstance(_component),
            "Trying to set derivatives, this is badly implemented currently.",
        )

        status = fmiSetReal(originalSetReal, _component, vrsDER, len_valuesDER, valuesDER)
        ret_status = max(ret_status, status)
    end

    # ... and we return the original status
    return ret_status
end

function mySetTime(_component::fmiComponent, time::fmiReal)
    global DERIVATIVES_VALID, originalSetTime
    DERIVATIVES_VALID = false

    return fmiSetTime(originalSetTime, _component, time)
end

function mySetContinuousStates(
    _component::fmiComponent,
    value::Union{AbstractArray{fmiReal},Ptr{fmiReal}},
    nx::Csize_t,
)
    global DERIVATIVES_VALID, originalSetContinuousStates
    DERIVATIVES_VALID = false

    return fmiSetContinuousStates(originalSetContinuousStates, _component, value, nx)
end

# this function is called, as soon as the DLL is loaded and Julia is initialized
# must return a FMU2- or FMU3-instance (depending on `FMI_VERSION`) to work with
FMIBUILD_CONSTRUCTOR = function (resPath)
    global originalGetDerivatives, originalGetReal, originalSetReal, originalSetTime, originalSetContinuousStates
    global fmu, ANN_PARAMETERS

    # loads an existing FMU
    fmu = loadFMU(joinpath(resPath, "SpringPendulum1D.fmu"))

    # create a FMU that embedds the existing FMU
    fmu = createFMUEmbedded(fmu)

    fmu.modelDescription.modelName = "NeuralFMU"
    fmu.modelDescription.modelExchange.modelIdentifier = "NeuralFMU"

    # deactivate special features, because they are not implemented yet
    setCapabilities!(
        fmu.modelDescription.modelExchange;
        canGetAndSetFMUState = false,
        canSerializeFMUState = false,
        providesDirectionalDerivatives = false,
    )
    fmu.modelDescription.coSimulation = nothing

    # save, where the original functions were stored, so we can access them in our new functions
    originalGetDerivatives = cGetDerivatives(fmu)
    originalGetReal = cGetReal(fmu)
    originalSetReal = cSetReal(fmu)
    originalSetTime = fmu.cSetTime
    originalSetContinuousStates = fmu.cSetContinuousStates

    # now we overwrite the original functions
    setFctGetDerivatives(fmu, myGetDerivatives!)
    setFctGetReal(fmu, myGetReal!)
    setFctSetReal(fmu, mySetReal)
    setFctSetTime(fmu, mySetTime)
    setFctSetContinuousStates(fmu, mySetContinuousStates)

    # additional parameters
    ANN_PARAMETERS = Array{fmiValueReference,1}()

    vr = fmiValueReference(1)
    for l = 1:length(model)
        if isa(model[l], Dense)
            for i = 1:size(model[l].W)[1]
                for j = 1:size(model[l].W)[2]
                    addRealParameter(
                        fmu,
                        "layer$(l)_W$(i)_$(j)";
                        description = "ANN parameter in layer $l for weight matrix entry [$i,$j]",
                        valueReference = vr,
                        start = model[l].W[i, j],
                        variability = fmiVariabilityTunable,
                        initial = fmiInitialExact,
                    )
                    push!(ANN_PARAMETERS, vr)
                    vr += fmiValueReference(1)
                end
                addRealParameter(
                    fmu,
                    "layer$(l)_b$(i)";
                    description = "ANN parameter in layer $l for bias vector entry [$i]",
                    valueReference = vr,
                    start = model[l].b[i],
                    variability = fmiVariabilityTunable,
                    initial = fmiInitialExact,
                )
                push!(ANN_PARAMETERS, vr)
                vr += fmiValueReference(1)
            end
        end
    end

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
#     recordValues = [ANN_PARAMETERS..., "mass.s", "mass.v"],
#     parameters = Dict{fmiValueReference,Any}(fmiValueReference(1) => 2.0),
# )

# using Plots
# plot(solution)

tmpDir = mktempdir(; prefix = "fmibuildjl_test_", cleanup = false)
@info "Saving example files at: $(tmpDir)"
fmu_save_path = joinpath(tmpDir, "NeuralFMU.fmu")
# this must be excluded during export -done by FMIBUILD_NO_EXPORT marker-, because FMIBuild cannot execute itself (but it is able to build)
import FMIBuild: saveFMU
# this must be excluded during export -done by FMIBUILD_NO_EXPORT marker-, because saveFMU would start an infinite build loop with itself
saveFMU(
    fmu,
    fmu_save_path;
    compress = false,
    debug = true, # (debug=true allows debug messages, but is slow during execution!)
    resources = Dict(sourceFMU => "SpringPendulum1D.fmu"),
)
unloadFMU(fmu)

# The following line is a end-marker for excluded code for the FMU compilation process!
### FMIBUILD_NO_EXPORT_END ###
