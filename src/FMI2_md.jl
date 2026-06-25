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

function createModelDescription()
    md = fmi2ModelDescription()
    md.guid = UUIDs.uuid1()
    md.generationDateAndTime = Dates.now()
    md.variableNamingConvention = fmi2VariableNamingConventionStructured
    md.numberOfEventIndicators = 0
    md.stringValueReferences = Dict{String,fmi2ValueReference}()

    return md
end
createModelDescription(::FMU2) = createModelDescription()
export createModelDescription

function fmi2ModelDescriptionAddModelExchange(
    md::fmi2ModelDescription,
    modelIdentifier::String=md.modelName,
)
    if isnothing(md.modelExchange)
        md.modelExchange = fmi2ModelDescriptionModelExchange()
    end
    md.modelExchange.modelIdentifier = modelIdentifier
end
export fmi2ModelDescriptionAddModelExchange

function fmi2ModelDescriptionAddCoSimulation(
    md::fmi2ModelDescription,
    modelIdentifier::String=md.modelName;
    canHandleVariableCommunicationStepSize::Union{Bool,Nothing}=true,
    canInterpolateInputs::Union{Bool,Nothing}=nothing,
    maxOutputDerivativeOrder::Union{UInt,Nothing}=nothing,
    canGetAndSetFMUstate::Union{Bool,Nothing}=false,
    canSerializeFMUstate::Union{Bool,Nothing}=false,
    providesDirectionalDerivative::Union{Bool,Nothing}=false,
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
export fmi2ModelDescriptionAddCoSimulation

function fmi2ModelDescriptionAddEvent(md::fmi2ModelDescription)
    md.numberOfEventIndicators += 1
end
export fmi2ModelDescriptionAddEvent

function fmi2GetIndexOfScalarVariable(md::fmi2ModelDescription, sv::fmi2ScalarVariable)
    for i = 1:length(md.modelVariables)
        if md.modelVariables[i] == sv
            return UInt(i)
        end
    end
    @assert false "fmi2GetIndexOfScalarVariable(...): Scalar variable is not part of the model variables."
end
export fmi2GetIndexOfScalarVariable

function fmi2ModelDescriptionAddRealState(
    md::fmi2ModelDescription,
    name::String;
    start::Union{Real,Nothing}=nothing,
    kwargs...,
)

    _Real = fmi2RealAttributesExt()
    _Real.start = start
    sv = fmi2ModelDescriptionAddModelVariable(
        md,
        name;
        attribute=_Real,
        initial=fmi2InitialExact,
        kwargs...,
    )

    push!(md.stateValueReferences, sv.valueReference)
    push!(md.stringValueReferences, sv.name => sv.valueReference)

    return sv
end
export fmi2ModelDescriptionAddRealState

function fmi2ModelDescriptionAddRealDerivative(
    md::fmi2ModelDescription,
    name::String;
    start::Union{Real,Nothing}=nothing,
    derivative::Union{UInt,Nothing}=nothing,
    kwargs...,
)

    _Real = fmi2RealAttributesExt()
    _Real.start = start
    _Real.derivative = derivative

    sv = fmi2ModelDescriptionAddModelVariable(md, name; attribute=_Real, kwargs...)
    index = fmi2GetIndexOfScalarVariable(md, sv)

    fmi2ModelDescriptionAddModelStructureDerivatives(md, index)
    fmi2ModelDescriptionAddModelStructureInitialUnknowns(md, index)

    push!(md.derivativeValueReferences, sv.valueReference)
    push!(md.stringValueReferences, sv.name => sv.valueReference)

    return sv
end
export fmi2ModelDescriptionAddRealDerivative

function fmi2ModelDescriptionAddRealStateAndDerivative(
    md::fmi2ModelDescription,
    stateName::String,
    derivativeName::String="der(" * stateName * ")";
    stateDescr::Union{String,Nothing}=nothing,
    derivativeDescr::Union{String,Nothing}=nothing,
    stateStart::Union{Real,Nothing}=nothing,
    derivativeStart::Union{Real,Nothing}=nothing,
)

    state = fmi2ModelDescriptionAddRealState(
        md,
        stateName;
        description=stateDescr,
        start=stateStart,
    )
    stateIndex = fmi2GetIndexOfScalarVariable(md, state)

    derivative = fmi2ModelDescriptionAddRealDerivative(
        md,
        derivativeName;
        derivative=stateIndex,
        description=derivativeDescr,
        start=derivativeStart,
    )

    return state, derivative
end
export fmi2ModelDescriptionAddRealStateAndDerivative

function fmi2ModelDescriptionAddRealInput(
    md::fmi2ModelDescription,
    name::String;
    start::Union{Real,Nothing}=nothing,
    kwargs...,
)

    _Real = fmi2RealAttributesExt()
    _Real.start = start

    sv = fmi2ModelDescriptionAddModelVariable(
        md,
        name;
        attribute=_Real,
        causality=fmi2CausalityInput,
        kwargs...,
    )

    push!(md.inputValueReferences, sv.valueReference)
    push!(md.stringValueReferences, sv.name => sv.valueReference)

    return sv
end
export fmi2ModelDescriptionAddRealInput

function fmi2ModelDescriptionAddRealOutput(
    md::fmi2ModelDescription,
    name::String;
    start::Union{Real,Nothing}=nothing,
    kwargs...,
)

    _Real = fmi2RealAttributesExt()
    _Real.start = start

    sv = fmi2ModelDescriptionAddModelVariable(
        md,
        name;
        attribute=_Real,
        causality=fmi2CausalityOutput,
        kwargs...,
    )
    index = fmi2GetIndexOfScalarVariable(md, sv)

    fmi2ModelDescriptionAddModelStructureOutputs(md, index)
    fmi2ModelDescriptionAddModelStructureInitialUnknowns(md, index)

    push!(md.outputValueReferences, sv.valueReference)
    push!(md.stringValueReferences, sv.name => sv.valueReference)

    return sv
end
export fmi2ModelDescriptionAddRealOutput

function fmi2ModelDescriptionAddRealParameter(
    md::fmi2ModelDescription,
    name::String;
    start::Union{Real,Nothing}=nothing,
    variability::fmi2Variability=fmi2VariabilityFixed,
    kwargs...,
)

    _Real = fmi2RealAttributesExt()
    _Real.start = start

    sv = fmi2ModelDescriptionAddModelVariable(
        md,
        name;
        attribute=_Real,
        causality=fmi2CausalityParameter,
        variability=variability,
        kwargs...,
    )

    push!(md.parameterValueReferences, sv.valueReference)
    push!(md.stringValueReferences, sv.name => sv.valueReference)

    return sv
end
export fmi2ModelDescriptionAddRealParameter

function fmi2ModelDescriptionAddIntegerDiscreteState(
    md::fmi2ModelDescription,
    name::String;
    start::Union{Real,Nothing}=nothing,
    kwargs...,
)

    _Integer = fmi2IntegerAttributesExt()
    _Integer.start = start

    sv = fmi2ModelDescriptionAddModelVariable(
        md,
        name;
        attribute=_Integer,
        variability=fmi2VariabilityDiscrete,
        kwargs...,
    )

    push!(md.discreteStateValueReferences, sv.valueReference)
    push!(md.stringValueReferences, sv.name => sv.valueReference)

    return sv
end
export fmi2ModelDescriptionAddIntegerDiscreteState

function fmi2ModelDescriptionAddEventIndicator(md::fmi2ModelDescription)
    if isnothing(md.numberOfEventIndicators)
        md.numberOfEventIndicators = 0
    end
    md.numberOfEventIndicators += 1
end
export fmi2ModelDescriptionAddEventIndicator

"""
Nothing = Skip entry 
"""
function fmi2ModelDescriptionAddModelVariable(
    md::fmi2ModelDescription,
    name::String;
    description::Union{String,Nothing}=nothing,
    valueReference::Union{fmi2ValueReference,Symbol}=:auto,
    causality::Union{fmi2Causality,Nothing}=nothing,
    variability::Union{fmi2Variability,Nothing}=nothing,
    initial::Union{fmi2Initial,Nothing}=nothing,
    canHandleMultipleSetPerTimeInstant::Union{Bool,Nothing}=nothing,
    attribute::Union{FMI2_SCALAR_VARIABLE_ATTRIBUTE_STRUCT,Nothing}=nothing,
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
export fmi2ModelDescriptionAddModelVariable

"""
Nothing = Skip entry 
"""
function fmi2ModelDescriptionAddModelStructureOutputs(
    md::fmi2ModelDescription,
    index::UInt;
    dependencies::Union{Array{UInt,1},Nothing}=nothing,
    dependenciesKind::Union{Array{fmi2DependencyKind,1},Nothing}=nothing,
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
export fmi2ModelDescriptionAddModelStructureOutputs

"""
Nothing = Skip entry 
"""
function fmi2ModelDescriptionAddModelStructureDerivatives(
    md::fmi2ModelDescription,
    index::UInt;
    dependencies::Union{Array{UInt,1},Nothing}=nothing,
    dependenciesKind::Union{Array{fmi2DependencyKind,1},Nothing}=nothing,
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
export fmi2ModelDescriptionAddModelStructureDerivatives

"""
Nothing = Skip entry 
"""
function fmi2ModelDescriptionAddModelStructureInitialUnknowns(
    md::fmi2ModelDescription,
    index::UInt;
    dependencies::Union{Array{UInt,1},Nothing}=nothing,
    dependenciesKind::Union{Array{fmi2DependencyKind,1},Nothing}=nothing,
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
export fmi2ModelDescriptionAddModelStructureInitialUnknowns
