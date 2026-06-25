#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

""" 
ToDo
"""
function createFMU2(modelName::String=""; type=fmi2TypeModelExchange)
    fmu = FMU2()

    fmu.modelName = modelName
    fmu.isZeroState = false
    fmu.type = type
    fmu.modelDescription = createModelDescription(fmu)
    fmu.fmuResourceLocation = pwd()

    return fmu
end
export createFMU2

""" 
ToDo
"""
function createFMU2Embedded(fmu::FMU; type=fmi2TypeModelExchange)
    global FMIBUILD_FMU

    FMIBUILD_FMU = fmu
    fmu.type = type

    # store function pointers to embedded FMU
    fmu.cFunctionPtrs["EMBEDDED_fmi2Instantiate"] = fmu.cInstantiate
    fmu.cFunctionPtrs["EMBEDDED_fmi2FreeInstance"] = fmu.cFreeInstance

    # a special instantiation function for embedded FMUs (enables FMI.jl interface)
    setFctInstantiate(fmu, embedded_fmi2Instantiate)

    # a special function for simple instance release (enables FMI.jl interface)
    setFctFreeInstance(fmu, embedded_fmi2FreeInstance)

    return fmu
end
export createFMU2Embedded

function fmi2AddRealStateAndDerivative(fmu::FMU2, stateName; kwargs...)
    return fmi2ModelDescriptionAddRealStateAndDerivative(
        fmu.modelDescription,
        stateName;
        kwargs...,
    )
end
const fmi2AddStateAndDerivative = fmi2AddRealStateAndDerivative

function fmi2AddIntegerDiscreteState(fmu::FMU2, stateName; kwargs...)
    return fmi2ModelDescriptionAddIntegerDiscreteState(
        fmu.modelDescription,
        stateName;
        kwargs...,
    )
end

function fmi2AddRealOutput(fmu::FMU2, name; kwargs...)
    return fmi2ModelDescriptionAddRealOutput(fmu.modelDescription, name; kwargs...)
end
const fmi2AddOutput = fmi2AddRealOutput

function fmi2AddRealInput(fmu::FMU2, name; kwargs...)
    return fmi2ModelDescriptionAddRealInput(fmu.modelDescription, name; kwargs...)
end
const fmi2AddInput = fmi2AddRealInput

function fmi2AddRealParameter(fmu::FMU2, name; kwargs...)
    return fmi2ModelDescriptionAddRealParameter(fmu.modelDescription, name; kwargs...)
end
const fmi2AddParameter = fmi2AddRealParameter

fmi2AddEventIndicator(fmu::FMU2) =
    fmi2ModelDescriptionAddEventIndicator(fmu.modelDescription)

function fmi2AddCoSimulation(fmu::FMU2, modelIdentifier::String; kwargs...)
    return fmi2ModelDescriptionAddCoSimulation(
        fmu.modelDescription,
        modelIdentifier;
        kwargs...,
    )
end

export fmi2AddIntegerDiscreteState
export fmi2AddRealStateAndDerivative, fmi2AddStateAndDerivative
export fmi2AddRealOutput, fmi2AddOutput
export fmi2AddRealInput, fmi2AddInput
export fmi2AddRealParameter, fmi2AddParameter
export fmi2AddEventIndicator, fmi2AddCoSimulation
