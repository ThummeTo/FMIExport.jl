#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

using FMIBase.EzXML
import UUIDs
import Dates

import FMIBase.FMICore: fmi2ModelDescriptionModelExchange, fmi2ModelDescriptionCoSimulation
import FMIBase.FMICore:
    fmi2RealAttributesExt,
    fmi2IntegerAttributesExt,
    fmi2BooleanAttributesExt,
    fmi2StringAttributesExt,
    fmi2EnumerationAttributesExt

"""
    createModelDescription(::FMU2)

Create an empty FMI 2 model description with generated GUID, generation timestamp, and initialized value-reference bookkeeping.
"""
function createModelDescription(::FMU2)
    md = fmi2ModelDescription()
    md.guid = UUIDs.uuid1()
    md.generationDateAndTime = Dates.now()
    md.variableNamingConvention = fmi2VariableNamingConventionStructured
    md.numberOfEventIndicators = 0
    md.stringValueReferences = Dict{String,fmi2ValueReference}()

    return md
end
export createModelDescription

"""
    addModelExchange(md::fmi2ModelDescription, modelIdentifier=md.modelName)

Add or update the Model Exchange capability entry of an FMI 2 model description.
"""
function addModelExchange(md::fmi2ModelDescription, modelIdentifier::String = md.modelName)
    if isnothing(md.modelExchange)
        md.modelExchange = fmi2ModelDescriptionModelExchange()
    end
    md.modelExchange.modelIdentifier = modelIdentifier
end
# ToDo: this receipt could be for FMU instead of FMU2,
# this should be changed for all receipts in this file.
addModelExchange(fmu::FMU2, args...; kwargs...) =
    addModelExchange(fmu.modelDescription, args...; kwargs...)
export addModelExchange

"""
    addCoSimulation(md::fmi2ModelDescription, modelIdentifier=md.modelName; kwargs...)

Add or update the Co-Simulation capability entry of an FMI 2 model description.
"""
function addCoSimulation(
    md::fmi2ModelDescription,
    modelIdentifier::String = md.modelName;
    canHandleVariableCommunicationStepSize::Union{Bool,Nothing} = true,
    canInterpolateInputs::Union{Bool,Nothing} = nothing,
    maxOutputDerivativeOrder::Union{UInt,Nothing} = nothing,
    canGetAndSetFMUstate::Union{Bool,Nothing} = false,
    canSerializeFMUstate::Union{Bool,Nothing} = false,
    providesDirectionalDerivative::Union{Bool,Nothing} = false,
)
    if isnothing(md.coSimulation)
        md.coSimulation = fmi2ModelDescriptionCoSimulation()
    end

    md.coSimulation.modelIdentifier = modelIdentifier
    md.coSimulation.canHandleVariableCommunicationStepSize =
        canHandleVariableCommunicationStepSize
    md.coSimulation.canInterpolateInputs = canInterpolateInputs
    md.coSimulation.maxOutputDerivativeOrder = maxOutputDerivativeOrder
    md.coSimulation.canGetAndSetFMUstate = canGetAndSetFMUstate
    md.coSimulation.canSerializeFMUstate = canSerializeFMUstate
    md.coSimulation.providesDirectionalDerivative = providesDirectionalDerivative

    return md.coSimulation
end
addCoSimulation(fmu::FMU2, args...; kwargs...) =
    addCoSimulation(fmu.modelDescription, args...; kwargs...)
export addCoSimulation

"""
    addEvent(md::fmi2ModelDescription)

Increase the number of event indicators stored in an FMI 2 model description.
"""
function addEvent(md::fmi2ModelDescription)
    md.numberOfEventIndicators += 1
end
addEvent(fmu::FMU2, args...; kwargs...) = addEvent(fmu.modelDescription, args...; kwargs...)
export addEvent

"""
    getIndexOfScalarVariable(md::fmi2ModelDescription, sv::fmi2ScalarVariable)

Return the one-based FMI model-variable index for `sv` in `md`.
"""
function getIndexOfScalarVariable(md::fmi2ModelDescription, sv::fmi2ScalarVariable)
    for i = 1:length(md.modelVariables)
        if md.modelVariables[i] == sv
            return UInt(i)
        end
    end
    @assert false "getIndexOfScalarVariable(...): Scalar variable is not part of the model variables."
end
export getIndexOfScalarVariable

"""
    addRealState(md::fmi2ModelDescription, name; start=nothing, kwargs...)

Add a real continuous state variable to an FMI 2 model description.
"""
function addRealState(
    md::fmi2ModelDescription,
    name::String;
    start::Union{Real,Nothing} = nothing,
    kwargs...,
)

    _Real = fmi2RealAttributesExt()
    _Real.start = start
    sv =
        addModelVariable(md, name; attribute = _Real, initial = fmi2InitialExact, kwargs...)

    push!(md.stateValueReferences, sv.valueReference)
    push!(md.stringValueReferences, sv.name => sv.valueReference)

    return sv
end
addRealState(fmu::FMU2, args...; kwargs...) =
    addRealState(fmu.modelDescription, args...; kwargs...)
export addRealState

"""
    addRealDerivative(md::fmi2ModelDescription, name; start=nothing, derivative=nothing, kwargs...)

Add a real derivative variable and corresponding model-structure entries to an FMI 2 model description.
"""
function addRealDerivative(
    md::fmi2ModelDescription,
    name::String;
    start::Union{Real,Nothing} = nothing,
    derivative::Union{UInt,Nothing} = nothing,
    kwargs...,
)

    _Real = fmi2RealAttributesExt()
    _Real.start = start
    _Real.derivative = derivative

    sv = addModelVariable(md, name; attribute = _Real, kwargs...)
    index = getIndexOfScalarVariable(md, sv)

    addModelStructureDerivatives(md, index)
    addModelStructureInitialUnknowns(md, index)

    push!(md.derivativeValueReferences, sv.valueReference)
    push!(md.stringValueReferences, sv.name => sv.valueReference)

    return sv
end
addRealDerivative(fmu::FMU2, args...; kwargs...) =
    addRealDerivative(fmu.modelDescription, args...; kwargs...)
export addRealDerivative

"""
    addRealStateAndDerivative(md::fmi2ModelDescription, stateName, derivativeName="der(" * stateName * ")"; kwargs...)

Add a real state and its derivative variable to an FMI 2 model description.
"""
function addRealStateAndDerivative(
    md::fmi2ModelDescription,
    stateName::String,
    derivativeName::String = "der(" * stateName * ")";
    stateDescr::Union{String,Nothing} = nothing,
    derivativeDescr::Union{String,Nothing} = nothing,
    stateStart::Union{Real,Nothing} = nothing,
    derivativeStart::Union{Real,Nothing} = nothing,
)

    state = addRealState(md, stateName; description = stateDescr, start = stateStart)
    stateIndex = getIndexOfScalarVariable(md, state)

    derivative = addRealDerivative(
        md,
        derivativeName;
        derivative = stateIndex,
        description = derivativeDescr,
        start = derivativeStart,
    )

    return state, derivative
end
addRealStateAndDerivative(fmu::FMU2, args...; kwargs...) =
    addRealStateAndDerivative(fmu.modelDescription, args...; kwargs...)
const addStateAndDerivative = addRealStateAndDerivative
export addRealStateAndDerivative, addStateAndDerivative

"""
    addRealInput(md::fmi2ModelDescription, name; start=nothing, kwargs...)

Add a real input variable to an FMI 2 model description.
"""
function addRealInput(
    md::fmi2ModelDescription,
    name::String;
    start::Union{Real,Nothing} = nothing,
    kwargs...,
)

    _Real = fmi2RealAttributesExt()
    _Real.start = start

    sv = addModelVariable(
        md,
        name;
        attribute = _Real,
        causality = fmi2CausalityInput,
        kwargs...,
    )

    push!(md.inputValueReferences, sv.valueReference)
    push!(md.stringValueReferences, sv.name => sv.valueReference)

    return sv
end
addRealInput(fmu::FMU2, args...; kwargs...) =
    addRealInput(fmu.modelDescription, args...; kwargs...)
const addInput = addRealInput
export addRealInput, addInput

"""
    addRealOutput(md::fmi2ModelDescription, name; start=nothing, kwargs...)

Add a real output variable and corresponding model-structure entries to an FMI 2 model description.
"""
function addRealOutput(
    md::fmi2ModelDescription,
    name::String;
    start::Union{Real,Nothing} = nothing,
    kwargs...,
)

    _Real = fmi2RealAttributesExt()
    _Real.start = start

    sv = addModelVariable(
        md,
        name;
        attribute = _Real,
        causality = fmi2CausalityOutput,
        kwargs...,
    )
    index = getIndexOfScalarVariable(md, sv)

    addModelStructureOutputs(md, index)
    addModelStructureInitialUnknowns(md, index)

    push!(md.outputValueReferences, sv.valueReference)
    push!(md.stringValueReferences, sv.name => sv.valueReference)

    return sv
end
addRealOutput(fmu::FMU2, args...; kwargs...) =
    addRealOutput(fmu.modelDescription, args...; kwargs...)
const addOutput = addRealOutput
export addRealOutput, addOutput

"""
    addRealParameter(md::fmi2ModelDescription, name; start=nothing, variability=fmi2VariabilityFixed, kwargs...)

Add a real parameter variable to an FMI 2 model description.
"""
function addRealParameter(
    md::fmi2ModelDescription,
    name::String;
    start::Union{Real,Nothing} = nothing,
    variability::fmi2Variability = fmi2VariabilityFixed,
    kwargs...,
)

    _Real = fmi2RealAttributesExt()
    _Real.start = start

    sv = addModelVariable(
        md,
        name;
        attribute = _Real,
        causality = fmi2CausalityParameter,
        variability = variability,
        kwargs...,
    )

    push!(md.parameterValueReferences, sv.valueReference)
    push!(md.stringValueReferences, sv.name => sv.valueReference)

    return sv
end
addRealParameter(fmu::FMU2, args...; kwargs...) =
    addRealParameter(fmu.modelDescription, args...; kwargs...)
const addParameter = addRealParameter
export addRealParameter, addParameter

"""
    addIntegerDiscreteState(md::fmi2ModelDescription, name; start=nothing, kwargs...)

Add an integer discrete state variable to an FMI 2 model description.
"""
function addIntegerDiscreteState(
    md::fmi2ModelDescription,
    name::String;
    start::Union{Real,Nothing} = nothing,
    kwargs...,
)

    _Integer = fmi2IntegerAttributesExt()
    _Integer.start = start

    sv = addModelVariable(
        md,
        name;
        attribute = _Integer,
        variability = fmi2VariabilityDiscrete,
        kwargs...,
    )

    push!(md.discreteStateValueReferences, sv.valueReference)
    push!(md.stringValueReferences, sv.name => sv.valueReference)

    return sv
end
addIntegerDiscreteState(fmu::FMU2, args...; kwargs...) =
    addIntegerDiscreteState(fmu.modelDescription, args...; kwargs...)
export addIntegerDiscreteState

"""
    addEventIndicator(md::fmi2ModelDescription)

Increase the number of event indicators in an FMI 2 model description.
"""
function addEventIndicator(md::fmi2ModelDescription)
    if isnothing(md.numberOfEventIndicators)
        md.numberOfEventIndicators = 0
    end
    md.numberOfEventIndicators += 1
end
addEventIndicator(fmu::FMU2, args...; kwargs...) =
    addEventIndicator(fmu.modelDescription, args...; kwargs...)
export addEventIndicator

"""
Nothing = Skip entry 
"""
function addModelVariable(
    md::fmi2ModelDescription,
    name::String;
    description::Union{String,Nothing} = nothing,
    valueReference::Union{fmi2ValueReference,Symbol} = :auto,
    causality::Union{fmi2Causality,Nothing} = nothing,
    variability::Union{fmi2Variability,Nothing} = nothing,
    initial::Union{fmi2Initial,Nothing} = nothing,
    canHandleMultipleSetPerTimeInstant::Union{Bool,Nothing} = nothing,
    attribute::Union{FMI2_SCALAR_VARIABLE_ATTRIBUTE_STRUCT,Nothing} = nothing,
)

    if valueReference === :auto
        valueReference = fmi2ValueReference(length(md.modelVariables) + 1)
    end

    sv = fmi2ScalarVariable(name, valueReference, causality, variability, initial)
    sv.description = description
    sv.canHandleMultipleSetPerTimeInstant = canHandleMultipleSetPerTimeInstant
    sv.attribute = attribute

    push!(md.modelVariables, sv)
    return sv
end
addModelVariable(fmu::FMU2, args...; kwargs...) =
    addModelVariable(fmu.modelDescription, args...; kwargs...)
export addModelVariable

"""
Nothing = Skip entry 
"""
function addModelStructureOutputs(
    md::fmi2ModelDescription,
    index::UInt;
    dependencies::Union{Array{UInt,1},Nothing} = nothing,
    dependenciesKind::Union{Array{fmi2DependencyKind,1},Nothing} = nothing,
)

    sd = fmi2VariableDependency(index)
    sd.dependencies = dependencies
    sd.dependenciesKind = dependenciesKind

    if md.modelStructure.outputs === nothing
        md.modelStructure.outputs = Array{fmi2VariableDependency,1}()
    end
    push!(md.modelStructure.outputs, sd)
    return sd
end
addModelStructureOutputs(fmu::FMU2, args...; kwargs...) =
    addModelStructureOutputs(fmu.modelDescription, args...; kwargs...)
export addModelStructureOutputs

"""
Nothing = Skip entry 
"""
function addModelStructureDerivatives(
    md::fmi2ModelDescription,
    index::UInt;
    dependencies::Union{Array{UInt,1},Nothing} = nothing,
    dependenciesKind::Union{Array{fmi2DependencyKind,1},Nothing} = nothing,
)

    sd = fmi2VariableDependency(index)
    sd.dependencies = dependencies
    sd.dependenciesKind = dependenciesKind

    if md.modelStructure.derivatives === nothing
        md.modelStructure.derivatives = Array{fmi2VariableDependency,1}()
    end
    push!(md.modelStructure.derivatives, sd)
    return sd
end
addModelStructureDerivatives(fmu::FMU2, args...; kwargs...) =
    addModelStructureDerivatives(fmu.modelDescription, args...; kwargs...)
export addModelStructureDerivatives

"""
Nothing = Skip entry 
"""
function addModelStructureInitialUnknowns(
    md::fmi2ModelDescription,
    index::UInt;
    dependencies::Union{Array{UInt,1},Nothing} = nothing,
    dependenciesKind::Union{Array{fmi2DependencyKind,1},Nothing} = nothing,
)

    sd = fmi2VariableDependency(index)
    sd.dependencies = dependencies
    sd.dependenciesKind = dependenciesKind

    if md.modelStructure.initialUnknowns === nothing
        md.modelStructure.initialUnknowns = Array{fmi2Unknown,1}()
    end
    push!(md.modelStructure.initialUnknowns, sd)
    return sd
end
addModelStructureInitialUnknowns(fmu::FMU2, args...; kwargs...) =
    addModelStructureInitialUnknowns(fmu.modelDescription, args...; kwargs...)
export addModelStructureInitialUnknowns
