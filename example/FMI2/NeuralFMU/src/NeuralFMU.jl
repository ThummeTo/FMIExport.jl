#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

using FMIExport: Dense, Chain
using FMIExport: fmi2SetFctGetDerivatives, fmi2SetFctGetReal, fmi2SetFctSetReal, fmi2SetFctSetTime, fmi2SetFctSetContinuousStates
using FMIExport: fmi2CreateEmbedded
using FMIExport: fmi2AddRealParameter
using FMIExport.FMICore: fmi2Real, fmi2Component, fmi2StatusOK, fmi2ValueReference
using FMIExport.FMICore: fmi2CausalityParameter, fmi2VariabilityTunable, fmi2InitialExact
using FMIImport: fmi2Load
import FMIExport

fmu = nothing

originalGetDerivatives = nothing # function pointer to the original fmi2GetDerivatives! c-function
originalGetReal = nothing # function pointer to the original fmi2GetReal c-function
originalSetReal = nothing # function pointer to the original fmi2SetReal c-function
originalSetTime = nothing
originalSetContinuousStates = nothing

model = Chain(Dense{Float64}(2, 2, identity),
              Dense{Float64}(2, 2, identity))
model[1].W[1,1] = 1.0
model[1].W[2,2] = 0.5
model[2].W[1,1] = 1.0
model[2].W[2,2] = 1.0

function getParameter(vrs)

    values = []

    for vr in vrs
        for l in 1:length(model)
            layer = model[l]

            if isa(layer, Dense)
                for i in 1:size(layer.W)[1]
                    for j in 1:size(layer.W)[2]

                        vr -= 1
                        if vr == 0
                            push!(values, layer.W[i,j])
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

    for v in 1:length(vrs)
        vr = vrs[v]
        value = values[v]

        for l in 1:length(model)
            layer = model[l]

            for i in 1:size(layer.W)[1]
                for j in 1:size(layer.W)[2]

                    vr -= 1
                    if vr == 0
                        layer.W[i,j] = value 
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

    valuesFMU = Array{fmi2Real, 1}()
    vrsFMU = Array{fmi2ValueReference, 1}()
    idxFMU = Array{Integer, 1}()

    valuesDER =Array{fmi2Real, 1}()
    vrsDER = Array{fmi2ValueReference, 1}()
    idxDER = Array{Integer, 1}()

    valuesANN =Array{fmi2Real, 1}()
    vrsANN = Array{fmi2ValueReference, 1}()
    idxANN = Array{Integer, 1}()

    for i in 1:length(vrs)
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
global DERIVATIVES = Array{fmi2Real}(undef, 2)
function updateDerivatives(_component::fmi2Component, ndx::Csize_t)

    global DERIVATIVES_VALID, DERIVATIVES
    global originalGetDerivatives, d

    status = fmi2StatusOK

    if !DERIVATIVES_VALID
        # first, we do what the original function does
        status = FMIExport.FMICore.fmi2GetDerivatives!(originalGetDerivatives, _component, DERIVATIVES, ndx)

        if status != fmi2StatusOK
            logError(_component, "fmi2GetDerivatives failed!")
            return fmi2StatusError
        end

        tmp = model(DERIVATIVES)
        DERIVATIVES[:] = tmp[:]
        DERIVATIVES_VALID = true
    end

    return status
end

# custom function for fmi2GetReal!(fmi2Component, Union{Array{fmi2ValueReference}, Ptr{fmi2ValueReference}}, Csize_t, value::Union{Array{fmi2Real}, Ptr{fmi2Real}}::fmi2Status
# for information on how the FMI2-functions are structured, have a look inside FMICore.jl/src/FMI2_c.jl or the FMI2.0.3-specification on fmi-standard.org
function myGetDerivatives!(_component::fmi2Component,
    derivatives::Union{AbstractArray{fmi2Real}, Ptr{fmi2Real}},
    ndx::Csize_t)

    global DERIVATIVES
    status = updateDerivatives(_component, ndx)

    # if we have a pointer to an array, we must interprete it as array to access elements
    if isa(derivatives, Ptr{fmi2Real})
        derivatives = unsafe_wrap(Array{fmi2Real}, derivatives, ndx, own=false)
    end

    derivatives[:] = DERIVATIVES[:]
    
    # ... and we return the original status
    return status
end

# custom function for fmi2GetReal!(fmi2Component, Union{Array{fmi2ValueReference}, Ptr{fmi2ValueReference}}, Csize_t, value::Union{Array{fmi2Real}, Ptr{fmi2Real}}::fmi2Status
# for information on how the FMI2-functions are structured, have a look inside FMICore.jl/src/FMI2_c.jl or the FMI2.0.3-specification on fmi-standard.org
function myGetReal!(_component::fmi2Component, vr::Union{AbstractArray{fmi2ValueReference}, Ptr{fmi2ValueReference}}, nvr::Csize_t, value::Union{AbstractArray{fmi2Real}, Ptr{fmi2Real}})
    global originalGetReal, fmu
    global DERIVATIVES

    # if we have a pointer to an array, we must interprete it as array to access elements
    if isa(value, Ptr{fmi2Real})
        value = unsafe_wrap(Array{fmi2Real}, value, nvr, own=false)
    end

    if isa(vr, Ptr{fmi2ValueReference})
        vr = unsafe_wrap(Array{fmi2ValueReference}, vr, nvr, own=false)
    end

    valuesFMU, vrsFMU, idxFMU, valuesDER, vrsDER, idxDER, valuesANN, vrsANN, idxANN = sortVRs(fmu, vr, value)

    ret_status = fmi2StatusOK

    if length(valuesANN) > 0
        value[idxANN] = getParameter(vrsANN)
    end

    if length(valuesDER) > 0

        ndx = Csize_t(length(fmu.modelDescription.derivativeValueReferences))
        updateDerivatives(_component, ndx)

        for i in 1:length(valuesDER)

            idDER = idxDER[i]
            vrDER = vrsDER[i]

            dind = 0
            
            for j in 1:ndx
                if vrDER == fmu.modelDescription.derivativeValueReferences[j]
                    dind = j 
                    break
                end
            end

            if dind == 0
                logError(_component, "Can not find value reference in derivatives for `$(vr[idDER])`.")
                return fmi2StatusError
            end

            value[idDER] = DERIVATIVES[dind]
        end
    end

    if length(valuesFMU) > 0
        status = FMIExport.FMICore.fmi2GetReal!(originalGetReal, _component, vrsFMU, Csize_t(1), valuesFMU)
        ret_status = max(ret_status, status)

        value[idxFMU] = valuesFMU[:]
    end

    # ... and we return the original status
    return ret_status
end
                   
function mySetReal(_component::fmi2Component, vr::Union{AbstractArray{fmi2ValueReference}, Ptr{fmi2ValueReference}}, nvr::Csize_t, value::Union{AbstractArray{fmi2Real}, Ptr{fmi2Real}})
    global originalSetReal
    global DERIVATIVES_VALID
    
    DERIVATIVES_VALID = false # invalidate derivatives

    # if we have a pointer to an array, we must interprete it as array to access elements
    if isa(value, Ptr{fmi2Real})
        value = unsafe_wrap(Array{fmi2Real}, value, nvr, own=false)
    else
        value = value
    end

    if isa(vr, Ptr{fmi2ValueReference})
        vr = unsafe_wrap(Array{fmi2ValueReference}, vr, nvr, own=false)
    else
        vr = vr
    end

    valuesFMU, vrsFMU, idxFMU, valuesDER, vrsDER, idxDER, valuesANN, vrsANN, idxANN = sortVRs(fmu, vr, value)

    ret_status = fmi2StatusOK

    if length(valuesANN) > 0
        setParameter(vrsANN, valuesANN)
    end

    len_valuesFMU = Csize_t(length(valuesFMU))
    if len_valuesFMU > 0
        status = FMIExport.FMICore.fmi2SetReal(originalSetReal, _component, vrsFMU, len_valuesFMU, valuesFMU)
        ret_status = max(ret_status, status)
    end

    len_valuesDER = Csize_t(length(valuesDER))
    if len_valuesDER > 0
        # ToDo: Here, a reverse propagation (by optimization) through the ANN is necessary!
        logWarning(_component, "fmi2GetDerivatives trying to set derivatives, this is badly implemented currently.")

        status = FMIExport.FMICore.fmi2SetReal(originalSetReal, _component, vrsDER, len_valuesDER, valuesDER)
        ret_status = max(ret_status, status)
    end

    # ... and we return the original status
    return ret_status
end

function mySetTime(_component::fmi2Component, time::fmi2Real)
    global DERIVATIVES_VALID, originalSetTime
    DERIVATIVES_VALID = false 

    return FMIExport.FMICore.fmi2SetTime(originalSetTime, _component, time)
end

function mySetContinuousStates(_component::fmi2Component, value::Union{AbstractArray{fmi2Real}, Ptr{fmi2Real}}, nx::Csize_t)
    global DERIVATIVES_VALID, originalSetContinuousStates
    DERIVATIVES_VALID = false 

    return FMIExport.FMICore.fmi2SetContinuousStates(originalSetContinuousStates, _component, value, nx)
end

# this function is called, as soon as the DLL is loaded and Julia is initialized 
# must return a FMU2-instance to work with
FMIBUILD_CONSTRUCTOR = function(resPath)
    global originalGetDerivatives, originalGetReal, originalSetReal, originalSetTime, originalSetContinuousStates
    global fmu, ANN_PARAMETERS

    # loads an existing FMU
    fmu = fmi2Load(joinpath(resPath, "SpringDamperPendulum1D.fmu"))

    # create a FMU that embedds the existing FMU
    fmu = fmi2CreateEmbedded(fmu)

    fmu.modelDescription.modelName = "NeuralFMU"
    fmu.modelDescription.modelExchange.modelIdentifier = "NeuralFMU"

    # deactivate special features, because they are not implemented yet
    fmu.modelDescription.modelExchange.canGetAndSetFMUstate = false
    fmu.modelDescription.modelExchange.canSerializeFMUstate = false
    fmu.modelDescription.modelExchange.providesDirectionalDerivative = false
    fmu.modelDescription.coSimulation = nothing

    # save, where the original functions were stored, so we can access them in our new functions
    originalGetDerivatives = fmu.cGetDerivatives
    originalGetReal = fmu.cGetReal
    originalSetReal = fmu.cSetReal
    originalSetTime = fmu.cSetTime
    originalSetContinuousStates = fmu.cSetContinuousStates

    # now we overwrite the original functions
    fmi2SetFctGetDerivatives(fmu, myGetDerivatives!)
    fmi2SetFctGetReal(fmu, myGetReal!)
    fmi2SetFctSetReal(fmu, mySetReal)
    fmi2SetFctSetTime(fmu, mySetTime)
    fmi2SetFctSetContinuousStates(fmu, mySetContinuousStates)

    # additional parameters 
    ANN_PARAMETERS = Array{fmi2ValueReference, 1}()

    vr = fmi2ValueReference(1)
    for l in 1:length(model)
        if isa(model[l], Dense)
            for i in 1:size(model[l].W)[1]
                for j in 1:size(model[l].W)[2]
                    fmi2AddRealParameter(fmu, "layer$(l)_W$(i)_$(j)";     description="ANN parameter in layer $l for weight matrix entry [$i,$j]", valueReference=vr, start=model[l].W[i,j], causality=fmi2CausalityParameter, variability=fmi2VariabilityTunable, initial=fmi2InitialExact)
                    push!(ANN_PARAMETERS, vr)
                    vr += fmi2ValueReference(1)
                end
                fmi2AddRealParameter(fmu, "layer$(l)_b$(i)";     description="ANN parameter in layer $l for bias vector entry [$i]", valueReference=vr, start=model[l].b[i], causality=fmi2CausalityParameter, variability=fmi2VariabilityTunable, initial=fmi2InitialExact)
                push!(ANN_PARAMETERS, vr)
                vr += fmi2ValueReference(1)
            end
        end
    end

    return fmu
end

### FMIBUILD_NO_EXPORT_BEGIN ###
# The line above is a start-marker for excluded code for the FMU compilation process!

import FMIZoo

tmpDir = mktempdir(; prefix="fmibuildjl_test_", cleanup=false) 
@info "Saving example files at: $(tmpDir)"
fmu_save_path = joinpath(tmpDir, "NeuralFMU.fmu")  

sourceFMU = FMIZoo.get_model_filename("SpringDamperPendulum1D", "Dymola", "2022x")
fmu = FMIBUILD_CONSTRUCTOR(dirname(sourceFMU))
import FMIBuild:fmi2Save        # <= this must be excluded during export, because FMIBuild cannot execute itself (but it is able to build)
fmi2Save(fmu, fmu_save_path; compress=true, resources=Dict(sourceFMU=>"SpringDamperPendulum1D.fmu"))    # <= this must be excluded during export, because fmi2Save would start an infinte build loop with itself 

### some tests ###
using FMI
fmu.executionConfig.loggingOn = true
solution = fmiSimulateME(fmu, (0.0, 5.0); dtmax=0.1, recordValues=[ANN_PARAMETERS..., fmi2ValueReference(16777219), fmi2ValueReference(335544321)], parameters=Dict{fmi2ValueReference, Any}(fmi2ValueReference(1)=>2.0, fmi2ValueReference(335544321)=>1.23))
using Plots
fmiPlot(solution)

# The following line is a end-marker for excluded code for the FMU compilation process!
### FMIBUILD_NO_EXPORT_END ###
