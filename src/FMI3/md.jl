#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

import FMIBase.FMICore:
    fmi3ModelDescriptionModelExchange,
    fmi3ModelDescriptionCoSimulation,
    fmi3VariableFloat64,
    fmi3VariableInt32

"""
    createModelDescription(::FMU3)

Create an FMI 3 model description with generated instantiation token, generation timestamp, initialized value-reference bookkeeping and the independent variable `time` (value reference 0).
"""
function createModelDescription(fmu::FMU3)
    md = fmi3ModelDescription()
    md.fmiVersion = "3.0"
    md.modelName = fmu.modelName
    md.instantiationToken = "{$(UUIDs.uuid1())}"
    md.generationDateAndTime = Dates.now()
    md.variableNamingConvention = fmi3VariableNamingConventionStructured
    md.numberOfEventIndicators = 0
    md.numberOfContinuousStates = 0
    md.stringValueReferences = Dict{String,fmi3ValueReference}()
    md.intermediateUpdateValueReferences = fmi3ValueReference[]

    # [Note] FMI 3 requires exactly one independent variable
    addModelVariable(
        md,
        "time";
        valueReference = fmi3ValueReference(0),
        description = "Simulation time",
        causality = fmi3CausalityIndependent,
        variability = fmi3VariabilityContinuous,
        initial = nothing,
    )

    return md
end

"""
    addModelExchange(md::fmi3ModelDescription, modelIdentifier=md.modelName)

Add or update the Model Exchange capability entry of an FMI 3 model description.
"""
function addModelExchange(md::fmi3ModelDescription, modelIdentifier::String = md.modelName)
    if isnothing(md.modelExchange)
        md.modelExchange = fmi3ModelDescriptionModelExchange(modelIdentifier)
    end
    md.modelExchange.modelIdentifier = modelIdentifier
end
addModelExchange(fmu::FMU3, args...; kwargs...) =
    addModelExchange(fmu.modelDescription, args...; kwargs...)

"""
    addCoSimulation(md::fmi3ModelDescription, modelIdentifier=md.modelName; kwargs...)

Add or update the Co-Simulation capability entry of an FMI 3 model description.
"""
function addCoSimulation(
    md::fmi3ModelDescription,
    modelIdentifier::String = md.modelName;
    canHandleVariableCommunicationStepSize::Union{Bool,Nothing} = true,
    fixedInternalStepSize::Union{Real,Nothing} = nothing,
    maxOutputDerivativeOrder::Union{UInt,Nothing} = nothing,
    canGetAndSetFMUState::Union{Bool,Nothing} = false,
    canSerializeFMUState::Union{Bool,Nothing} = false,
    providesDirectionalDerivatives::Union{Bool,Nothing} = false,
    hasEventMode::Union{Bool,Nothing} = false,
)
    if isnothing(md.coSimulation)
        md.coSimulation = fmi3ModelDescriptionCoSimulation(modelIdentifier)
    end

    md.coSimulation.modelIdentifier = modelIdentifier
    md.coSimulation.canHandleVariableCommunicationStepSize =
        canHandleVariableCommunicationStepSize
    md.coSimulation.fixedInternalStepSize = fixedInternalStepSize
    md.coSimulation.maxOutputDerivativeOrder = maxOutputDerivativeOrder
    md.coSimulation.canGetAndSetFMUState = canGetAndSetFMUState
    md.coSimulation.canSerializeFMUState = canSerializeFMUState
    md.coSimulation.providesDirectionalDerivatives = providesDirectionalDerivatives
    md.coSimulation.hasEventMode = hasEventMode

    return md.coSimulation
end
addCoSimulation(fmu::FMU3, args...; kwargs...) =
    addCoSimulation(fmu.modelDescription, args...; kwargs...)

"""
    addRealState(md::fmi3ModelDescription, name; start=nothing, kwargs...)

Add a `Float64` continuous state variable to an FMI 3 model description.
"""
function addRealState(
    md::fmi3ModelDescription,
    name::String;
    start::Union{Real,Nothing} = nothing,
    kwargs...,
)

    var = addModelVariable(md, name; start = start, initial = fmi3InitialExact, kwargs...)

    push!(md.stateValueReferences, var.valueReference)
    md.numberOfContinuousStates = length(md.stateValueReferences)

    return var
end
addRealState(fmu::FMU3, args...; kwargs...) =
    addRealState(fmu.modelDescription, args...; kwargs...)

"""
    addRealDerivative(md::fmi3ModelDescription, name; start=nothing, derivative=nothing, kwargs...)

Add a `Float64` derivative variable and corresponding model-structure entries to an FMI 3 model description, `derivative` is the value reference of the state.
"""
function addRealDerivative(
    md::fmi3ModelDescription,
    name::String;
    start::Union{Real,Nothing} = nothing,
    derivative::Union{Integer,Nothing} = nothing,
    kwargs...,
)

    var = addModelVariable(
        md,
        name;
        start = start,
        initial = (isnothing(start) ? fmi3InitialCalculated : fmi3InitialApprox),
        kwargs...,
    )
    var.derivative = isnothing(derivative) ? nothing : fmi3ValueReference(derivative)

    addModelStructureDerivatives(md, var.valueReference)
    addModelStructureInitialUnknowns(md, var.valueReference)

    push!(md.derivativeValueReferences, var.valueReference)

    return var
end
addRealDerivative(fmu::FMU3, args...; kwargs...) =
    addRealDerivative(fmu.modelDescription, args...; kwargs...)

"""
    addRealStateAndDerivative(md::fmi3ModelDescription, stateName, derivativeName="der(" * stateName * ")"; kwargs...)

Add a `Float64` state and its derivative variable to an FMI 3 model description.
"""
function addRealStateAndDerivative(
    md::fmi3ModelDescription,
    stateName::String,
    derivativeName::String = "der(" * stateName * ")";
    stateDescr::Union{String,Nothing} = nothing,
    derivativeDescr::Union{String,Nothing} = nothing,
    stateStart::Union{Real,Nothing} = nothing,
    derivativeStart::Union{Real,Nothing} = nothing,
)

    state = addRealState(md, stateName; description = stateDescr, start = stateStart)

    derivative = addRealDerivative(
        md,
        derivativeName;
        derivative = state.valueReference,
        description = derivativeDescr,
        start = derivativeStart,
    )

    return state, derivative
end
addRealStateAndDerivative(fmu::FMU3, args...; kwargs...) =
    addRealStateAndDerivative(fmu.modelDescription, args...; kwargs...)

"""
    addRealInput(md::fmi3ModelDescription, name; start=0.0, kwargs...)

Add a `Float64` input variable to an FMI 3 model description.
"""
function addRealInput(md::fmi3ModelDescription, name::String; start::Real = 0.0, kwargs...)

    # [Note] FMI 3 inputs require a start value, but no `initial` attribute
    var = addModelVariable(
        md,
        name;
        start = start,
        causality = fmi3CausalityInput,
        initial = nothing,
        kwargs...,
    )

    push!(md.inputValueReferences, var.valueReference)

    return var
end
addRealInput(fmu::FMU3, args...; kwargs...) =
    addRealInput(fmu.modelDescription, args...; kwargs...)

"""
    addRealOutput(md::fmi3ModelDescription, name; start=nothing, kwargs...)

Add a `Float64` output variable and corresponding model-structure entries to an FMI 3 model description.
"""
function addRealOutput(
    md::fmi3ModelDescription,
    name::String;
    start::Union{Real,Nothing} = nothing,
    kwargs...,
)

    var = addModelVariable(
        md,
        name;
        start = start,
        causality = fmi3CausalityOutput,
        initial = (isnothing(start) ? fmi3InitialCalculated : fmi3InitialApprox),
        kwargs...,
    )

    addModelStructureOutputs(md, var.valueReference)
    addModelStructureInitialUnknowns(md, var.valueReference)

    push!(md.outputValueReferences, var.valueReference)

    return var
end
addRealOutput(fmu::FMU3, args...; kwargs...) =
    addRealOutput(fmu.modelDescription, args...; kwargs...)

"""
    addRealParameter(md::fmi3ModelDescription, name; start=nothing, variability=fmi3VariabilityFixed, kwargs...)

Add a `Float64` parameter variable to an FMI 3 model description.
"""
function addRealParameter(
    md::fmi3ModelDescription,
    name::String;
    start::Union{Real,Nothing} = nothing,
    variability::fmi3Variability = fmi3VariabilityFixed,
    kwargs...,
)

    var = addModelVariable(
        md,
        name;
        start = start,
        causality = fmi3CausalityParameter,
        variability = variability,
        initial = fmi3InitialExact,
        kwargs...,
    )

    push!(md.parameterValueReferences, var.valueReference)

    return var
end
addRealParameter(fmu::FMU3, args...; kwargs...) =
    addRealParameter(fmu.modelDescription, args...; kwargs...)

"""
    addIntegerDiscreteState(md::fmi3ModelDescription, name; start=nothing, kwargs...)

Add an `Int32` discrete state variable to an FMI 3 model description.
"""
function addIntegerDiscreteState(
    md::fmi3ModelDescription,
    name::String;
    start::Union{Real,Nothing} = nothing,
    kwargs...,
)

    var = addModelVariable(
        md,
        name;
        type = fmi3VariableInt32,
        start = start,
        variability = fmi3VariabilityDiscrete,
        initial = (isnothing(start) ? fmi3InitialCalculated : fmi3InitialExact),
        kwargs...,
    )

    push!(md.discreteStateValueReferences, var.valueReference)

    return var
end
addIntegerDiscreteState(fmu::FMU3, args...; kwargs...) =
    addIntegerDiscreteState(fmu.modelDescription, args...; kwargs...)

"""
    addEventIndicator(md::fmi3ModelDescription, name="eventIndicator_" * n)

Add an event indicator to an FMI 3 model description. In FMI 3, event indicators are `Float64` variables referenced in the model structure.
"""
function addEventIndicator(md::fmi3ModelDescription, name::Union{String,Nothing} = nothing)
    if isnothing(md.numberOfEventIndicators)
        md.numberOfEventIndicators = 0
    end
    md.numberOfEventIndicators += 1

    if isnothing(name)
        name = "eventIndicator_$(md.numberOfEventIndicators)"
    end

    var = addModelVariable(md, name; initial = nothing)
    addModelStructureEventIndicators(md, var.valueReference)
    push!(md.eventIndicatorValueReferences, var.valueReference)

    return var
end
addEventIndicator(fmu::FMU3, args...; kwargs...) =
    addEventIndicator(fmu.modelDescription, args...; kwargs...)
addEvent(md::fmi3ModelDescription, args...; kwargs...) =
    addEventIndicator(md, args...; kwargs...)
addEvent(fmu::FMU3, args...; kwargs...) = addEvent(fmu.modelDescription, args...; kwargs...)

"""
Nothing = Skip entry
"""
function addModelVariable(
    md::fmi3ModelDescription,
    name::String;
    type::Type{<:fmi3Variable} = fmi3VariableFloat64,
    description::Union{String,Nothing} = nothing,
    valueReference::Union{fmi3ValueReference,Symbol} = :auto,
    causality::fmi3Causality = fmi3CausalityLocal,
    variability::fmi3Variability = fmi3VariabilityContinuous,
    initial::Union{fmi3Initial,Nothing} = fmi3InitialCalculated,
    start::Union{Real,Nothing} = nothing,
)

    if valueReference === :auto
        valueReference = nextValueReference(md, fmi3ValueReference(0))
    else
        # value references must be unique in FMI 3 (aliases are `Alias` elements of a variable)
        i = findfirst(var -> var.valueReference == valueReference, md.modelVariables)
        if !isnothing(i)
            throw(
                ArgumentError(
                    "addModelVariable(...): Value reference $(valueReference) is already used by variable `$(md.modelVariables[i].name)`.",
                ),
            )
        end
    end

    var = type(name, valueReference)
    var.description = description
    var.causality = causality
    var.variability = variability
    var.initial = initial
    var.start = start

    push!(md.modelVariables, var)
    push!(md.stringValueReferences, var.name => var.valueReference)
    return var
end
addModelVariable(fmu::FMU3, args...; kwargs...) =
    addModelVariable(fmu.modelDescription, args...; kwargs...)

"""
Nothing = Skip entry
"""
function addModelStructureOutputs(
    md::fmi3ModelDescription,
    valueReference::Integer;
    dependencies::Union{Array{UInt,1},Nothing} = nothing,
    dependenciesKind::Union{Array{fmi3DependencyKind,1},Nothing} = nothing,
)
    sd = fmi3VariableDependency(valueReference)
    sd.dependencies = dependencies
    sd.dependenciesKind = dependenciesKind

    if isnothing(md.modelStructure.outputs)
        md.modelStructure.outputs = Array{fmi3VariableDependency,1}()
    end
    push!(md.modelStructure.outputs, sd)
    return sd
end
addModelStructureOutputs(fmu::FMU3, args...; kwargs...) =
    addModelStructureOutputs(fmu.modelDescription, args...; kwargs...)

"""
Nothing = Skip entry
"""
function addModelStructureDerivatives(
    md::fmi3ModelDescription,
    valueReference::Integer;
    dependencies::Union{Array{UInt,1},Nothing} = nothing,
    dependenciesKind::Union{Array{fmi3DependencyKind,1},Nothing} = nothing,
)
    sd = fmi3VariableDependency(valueReference)
    sd.dependencies = dependencies
    sd.dependenciesKind = dependenciesKind

    if isnothing(md.modelStructure.continuousStateDerivatives)
        md.modelStructure.continuousStateDerivatives = Array{fmi3VariableDependency,1}()
    end
    push!(md.modelStructure.continuousStateDerivatives, sd)
    return sd
end
addModelStructureDerivatives(fmu::FMU3, args...; kwargs...) =
    addModelStructureDerivatives(fmu.modelDescription, args...; kwargs...)

"""
Nothing = Skip entry
"""
function addModelStructureInitialUnknowns(
    md::fmi3ModelDescription,
    valueReference::Integer;
    dependencies::Union{Array{UInt,1},Nothing} = nothing,
    dependenciesKind::Union{Array{fmi3DependencyKind,1},Nothing} = nothing,
)
    sd = fmi3VariableDependency(valueReference)
    sd.dependencies = dependencies
    sd.dependenciesKind = dependenciesKind

    if isnothing(md.modelStructure.initialUnknowns)
        md.modelStructure.initialUnknowns = Array{fmi3VariableDependency,1}()
    end
    push!(md.modelStructure.initialUnknowns, sd)
    return sd
end
addModelStructureInitialUnknowns(fmu::FMU3, args...; kwargs...) =
    addModelStructureInitialUnknowns(fmu.modelDescription, args...; kwargs...)

"""
Nothing = Skip entry
"""
function addModelStructureEventIndicators(
    md::fmi3ModelDescription,
    valueReference::Integer;
    dependencies::Union{Array{UInt,1},Nothing} = nothing,
    dependenciesKind::Union{Array{fmi3DependencyKind,1},Nothing} = nothing,
)
    sd = fmi3VariableDependency(valueReference)
    sd.dependencies = dependencies
    sd.dependenciesKind = dependenciesKind

    if isnothing(md.modelStructure.eventIndicators)
        md.modelStructure.eventIndicators = Array{fmi3VariableDependency,1}()
    end
    push!(md.modelStructure.eventIndicators, sd)
    return sd
end
addModelStructureEventIndicators(fmu::FMU3, args...; kwargs...) =
    addModelStructureEventIndicators(fmu.modelDescription, args...; kwargs...)
export addModelStructureEventIndicators
