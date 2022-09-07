#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

using EzXML
import UUIDs
import Dates

function fmi2CreateModelDescription()
    md = fmi2ModelDescription()
    md.guid = UUIDs.uuid1()
    md.generationDateAndTime = Dates.now()
    md.variableNamingConvention = fmi2VariableNamingConventionStructured
    md.numberOfEventIndicators = 0
    md.stringValueReferences = Dict{String, fmi2ValueReference}()

    return md
end

function fmi2ModelDescriptionAddModelExchange(md::fmi2ModelDescription, modelIdentifier::String)
    if md.modelExchange == nothing 
        md.modelExchange = fmi2ModelDescriptionModelExchange()
    end
    md.modelExchange.modelIdentifier = modelIdentifier
end

function fmi2ModelDescriptionAddEvent(md::fmi2ModelDescription)
    md.numberOfEventIndicators += 1
end

function fmi2GetIndexOfScalarVariable(md::fmi2ModelDescription, sv::fmi2ScalarVariable)
    for i in 1:length(md.modelVariables)
        if md.modelVariables[i] == sv 
            return UInt(i) 
        end 
    end
    @assert false "fmi2GetIndexOfScalarVariable(...): Scalar variable is not part of the model variables."
end

function fmi2ModelDescriptionAddRealState(md::fmi2ModelDescription, name::String; 
    start::Union{Real, Nothing}=nothing,
    kwargs...)

    _Real = fmi2ModelDescriptionReal()
    _Real.start = start
    sv =  fmi2ModelDescriptionAddModelVariable(md, name; _Real=_Real, kwargs...)

    push!(md.stateValueReferences, sv.valueReference)
    push!(md.stringValueReferences, sv.name => sv.valueReference)
   
    return sv
end

function fmi2ModelDescriptionAddRealDerivative(md::fmi2ModelDescription, name::String; 
    start::Union{Real, Nothing}=nothing,
    derivative::Union{UInt, Nothing}=nothing,
    kwargs...)

    _Real = fmi2ModelDescriptionReal()
    _Real.start = start
    _Real.derivative = derivative

    sv = fmi2ModelDescriptionAddModelVariable(md, name; _Real=_Real, kwargs...)
    index = fmi2GetIndexOfScalarVariable(md, sv)

    fmi2ModelDescriptionAddModelStructureDerivatives(md, index)
    fmi2ModelDescriptionAddModelStructureInitialUnknowns(md, index)

    push!(md.derivativeValueReferences, sv.valueReference)
    push!(md.stringValueReferences, sv.name => sv.valueReference)

    return sv 
end

function fmi2ModelDescriptionAddRealStateAndDerivative(md::fmi2ModelDescription, stateName::String, derivativeName::String = "der(" * stateName * ")"; 
    stateDescr::Union{String, Nothing} = nothing,
    derivativeDescr::Union{String, Nothing} = nothing)

    state = fmi2ModelDescriptionAddRealState(md, stateName; description=stateDescr)
    stateIndex = fmi2GetIndexOfScalarVariable(md, state)
    derivative = fmi2ModelDescriptionAddRealDerivative(md, derivativeName; derivative=stateIndex, description=derivativeDescr)

    return state, derivative
end

function fmi2ModelDescriptionAddRealInput(md::fmi2ModelDescription, name::String; 
    start::Union{Real, Nothing}=nothing,
    kwargs...)

    _Real = fmi2ModelDescriptionReal()
    _Real.start = start

    sv = fmi2ModelDescriptionAddModelVariable(md, name; _Real=_Real, causality=fmi2CausalityInput, kwargs...)

    push!(md.inputValueReferences, sv.valueReference)
    push!(md.stringValueReferences, sv.name => sv.valueReference)

    return sv
end

function fmi2ModelDescriptionAddRealOutput(md::fmi2ModelDescription, name::String; 
    start::Union{Real, Nothing}=nothing,
    kwargs...)

    _Real = fmi2ModelDescriptionReal()
    _Real.start = start

    sv = fmi2ModelDescriptionAddModelVariable(md, name; _Real=_Real, causality=fmi2CausalityOutput, kwargs...)
    index = fmi2GetIndexOfScalarVariable(md, sv)

    fmi2ModelDescriptionAddModelStructureOutputs(md, index)
    push!(md.outputValueReferences, sv.valueReference)
    push!(md.stringValueReferences, sv.name => sv.valueReference)

    return sv
end

function fmi2ModelDescriptionAddRealParameter(md::fmi2ModelDescription, name::String; 
    start::Union{Real, Nothing}=nothing,
    kwargs...)

    _Real = fmi2ModelDescriptionReal()
    _Real.start = start
    
    sv = fmi2ModelDescriptionAddModelVariable(md, name; _Real=_Real, kwargs...)

    push!(md.parameterValueReferences, sv.valueReference)
    push!(md.stringValueReferences, sv.name => sv.valueReference)

    return sv
end

function fmi2ModelDescriptionAddEventIndicator(md::fmi2ModelDescription)
    if md.numberOfEventIndicators == nothing
        md.numberOfEventIndicators = 0
    end 
    md.numberOfEventIndicators += 1
end

"""
Nothing = Skip entry 
"""
function fmi2ModelDescriptionAddModelVariable(md::fmi2ModelDescription, name::String; 
    description::Union{String, Nothing}=nothing, 
    valueReference::Union{fmi2ValueReference, Symbol}=:auto,
    causality::Union{fmi2Causality, Nothing}=nothing,
    variability::Union{fmi2Variability, Nothing}=nothing,
    initial::Union{fmi2Initial, Nothing}=nothing,
    canHandleMultipleSetPerTimeInstant::Union{Bool, Nothing}=nothing,
    _Real::Union{fmi2ModelDescriptionReal, Nothing}=nothing,
    _Integer::Union{fmi2ModelDescriptionInteger, Nothing}=nothing,
    _Boolean::Union{fmi2ModelDescriptionBoolean, Nothing}=nothing,
    _String::Union{fmi2ModelDescriptionString, Nothing}=nothing,
    _Enumeration::Union{fmi2ModelDescriptionEnumeration, Nothing}=nothing)

    if valueReference === :auto 
        valueReference = fmi2ValueReference(length(md.modelVariables)+1)
    end

    sv = fmi2ScalarVariable(name, valueReference, causality, variability, initial)
    sv.description = description
    sv.canHandleMultipleSetPerTimeInstant = canHandleMultipleSetPerTimeInstant
    sv._Real = _Real
    sv._Integer = _Integer
    sv._Boolean = _Boolean
    sv._String = _String
    sv._Enumeration = _Enumeration

    push!(md.modelVariables, sv)
    return sv
end

"""
Nothing = Skip entry 
"""
function fmi2ModelDescriptionAddModelStructureOutputs(md::fmi2ModelDescription, index::UInt;
    dependencies::Union{Array{UInt, 1}, Nothing} = nothing,
    dependenciesKind::Union{Array{fmi2DependencyKind, 1}, Nothing} = nothing)

    sd = fmi2VariableDependency(index)
    sd.dependencies = dependencies
    sd.dependenciesKind = dependenciesKind

    if md.modelStructure.outputs === nothing 
        md.modelStructure.outputs = Array{fmi2VariableDependency, 1}()
    end 
    push!(md.modelStructure.outputs, sd)
    return sd
end

"""
Nothing = Skip entry 
"""
function fmi2ModelDescriptionAddModelStructureDerivatives(md::fmi2ModelDescription, index::UInt;
    dependencies::Union{Array{UInt, 1}, Nothing} = nothing,
    dependenciesKind::Union{Array{fmi2DependencyKind, 1}, Nothing} = nothing)

    sd = fmi2VariableDependency(index)
    sd.dependencies = dependencies
    sd.dependenciesKind = dependenciesKind

    if md.modelStructure.derivatives === nothing 
        md.modelStructure.derivatives = Array{fmi2VariableDependency, 1}()
    end 
    push!(md.modelStructure.derivatives, sd)
    return sd
end

"""
Nothing = Skip entry 
"""
function fmi2ModelDescriptionAddModelStructureInitialUnknowns(md::fmi2ModelDescription, index::UInt;
    dependencies::Union{Array{UInt, 1}, Nothing} = nothing,
    dependenciesKind::Union{Array{fmi2DependencyKind, 1}, Nothing} = nothing)

    sd = fmi2VariableDependency(index)
    sd.dependencies = dependencies
    sd.dependenciesKind = dependenciesKind

    if md.modelStructure.initialUnknowns === nothing 
        md.modelStructure.initialUnknowns = Array{fmi2Unknown, 1}()
    end 
    push!(md.modelStructure.initialUnknowns, sd)
    return sd
end