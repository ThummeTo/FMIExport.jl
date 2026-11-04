#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

# [Note] The FMI 3 simple FMU shares the model functions `FMU_FCT_*` with FMI 2 (see `FMI2/simple.jl`).
#        `fmi3Instance` and `fmi2Component` are the same type, so the instance helpers dispatch on `FMU3Instance`.

const STRING_VERSION_3_0 = "3.0"

# `FMU3Instance.values` stores `fmi3Float64`, `fmi3Int64` and `fmi3Boolean` values
toInstanceValue(x::Bool) = fmi3Boolean(x)
toInstanceValue(x::Integer) = fmi3Int64(x)
toInstanceValue(x::Real) = fmi3Float64(x)

fromInstanceValue(::Type{fmi3Boolean}, x) = (iszero(x) ? fmi3False : fmi3True)
fromInstanceValue(::Type{T}, x) where {T} = T(x)

function independentValueReference(md::fmi3ModelDescription)
    for var in md.modelVariables
        if var.causality == fmi3CausalityIndependent
            return var.valueReference
        end
    end
    return nothing
end

##############

function reset(instance::FMU3Instance)
    instance.t, xc, ẋc, xd, u, p = FMU_FCT_INIT()
    instance.z = FMU_FCT_EVENT(instance.t, xc, ẋc, xd, u, p)
    y = FMU_FCT_OUTPUT(instance.t, xc, ẋc, xd, u, p)

    applyValues(instance, xc, ẋc, xd, u, y, p)
    applyEventIndicators(instance)
end

function evaluate(instance::FMU3Instance, eventMode = false)
    xc, ẋc, xd, u, y, p = extractValues(instance)

    tmp_xc, ẋc, tmp_xd, p = FMU_FCT_EVALUATE(instance.t, xc, ẋc, xd, u, p, eventMode)

    if eventMode # overwrite state vector allowed
        if xc != tmp_xc
            instance.valuesOfContinuousStatesChanged = fmi3True
        end

        xc = tmp_xc
        xd = tmp_xd
    else
        if xd != tmp_xd
            logError(
                instance,
                "FMU_FCT_EVALUATE changes the systems discrete state while not being in event-mode, this is not allowed!",
            )
        end
    end

    y = FMU_FCT_OUTPUT(instance.t, xc, ẋc, xd, u, p)
    z_new = FMU_FCT_EVENT(instance.t, xc, ẋc, xd, u, p)

    applyValues(instance, xc, ẋc, xd, u, y, p)

    # event triggering
    if !isnothing(instance.z_prev) && (sign.(z_new) != sign.(instance.z_prev))
        instance.z_prev = z_new
        instance.z = z_new
    else
        instance.z_prev = instance.z
        instance.z = z_new
    end
    applyEventIndicators(instance)
end

function applyValues(instance::FMU3Instance, xc, ẋc, xd, u, y, p)
    md = instance.fmu.modelDescription

    for (vrs, values) in (
        (md.stateValueReferences, xc),
        (md.derivativeValueReferences, ẋc),
        (md.discreteStateValueReferences, xd),
        (md.inputValueReferences, u),
        (md.outputValueReferences, y),
        (md.parameterValueReferences, p),
    )
        for i = 1:length(vrs)
            instance.values[vrs[i]] = toInstanceValue(values[i])
        end
    end

    nothing
end

function applyEventIndicators(instance::FMU3Instance)
    vrs = instance.fmu.modelDescription.eventIndicatorValueReferences
    for i = 1:length(vrs)
        instance.values[vrs[i]] = toInstanceValue(instance.z[i])
    end

    nothing
end

function extractValues(instance::FMU3Instance)
    md = instance.fmu.modelDescription

    xcs = collect(instance.values[vr] for vr in md.stateValueReferences)
    ẋcs = collect(instance.values[vr] for vr in md.derivativeValueReferences)
    xds = collect(instance.values[vr] for vr in md.discreteStateValueReferences)
    us = collect(instance.values[vr] for vr in md.inputValueReferences)
    ys = collect(instance.values[vr] for vr in md.outputValueReferences)
    ps = collect(instance.values[vr] for vr in md.parameterValueReferences)

    return xcs, ẋcs, xds, us, ys, ps
end

function getValues(
    instance::FMU3Instance,
    _vr::Ptr{fmi3ValueReference},
    nvr::Csize_t,
    _values::Ptr{T},
    name::String,
) where {T}
    md = instance.fmu.modelDescription

    for i = 1:nvr
        vr = unsafe_load(_vr, i)
        value = get(instance.values, vr, nothing)

        if isnothing(value)
            if vr == independentValueReference(md)
                value = instance.t
            else
                logError(instance, "$(name): Unknown value reference $(vr).")
                return fmi3StatusError
            end
        end

        unsafe_store!(_values, fromInstanceValue(T, value), i)
    end

    return fmi3StatusOK
end

function setValues(
    instance::FMU3Instance,
    _vr::Ptr{fmi3ValueReference},
    nvr::Csize_t,
    _values::Ptr{T},
    name::String,
) where {T}
    for i = 1:nvr
        vr = unsafe_load(_vr, i)

        if !haskey(instance.values, vr)
            logError(instance, "$(name): Unknown value reference $(vr).")
            return fmi3StatusError
        end

        instance.values[vr] = toInstanceValue(unsafe_load(_values, i))
    end

    evaluate(instance)

    return fmi3StatusOK
end

# sets up the internal ME simulation that is used to compute CS steps
function prepareCoSimulation(instance::FMU3Instance)
    xc, ẋc, xd, u, y, p = extractValues(instance)

    instance.x = fmi3Float64.(xc)
    instance.x_d = fmi3Float64.(xd)
    instance.x_nominals = ones(fmi3Float64, length(xc))
    if isnothing(instance.solution) # e.g. allocated by the importer
        instance.solution = FMIBase.FMUSolution(instance)
    end

    instance.fmu.hasStateEvents =
        (instance.fmu.modelDescription.numberOfEventIndicators > 0)
    instance.fmu.hasTimeEvents = false

    instance.callback = FMIBase.setupCallbacks(
        instance,
        fmi3ValueReference[],
        nothing,
        false,
        nothing,
        fmi3ValueReference[],
        nothing,
        instance.t,
        typemax(fmi3Float64),
        nothing,
    )

    nothing
end

# returns a FMI function that is not supported by the simple FMU
function simple_fmi3NotSupported(name::String)
    return function (_instance, args...)
        logError(dereferenceInstance(_instance), "$(name): Not supported by this FMU.")
        return fmi3StatusError
    end
end

##############

# inquire version numbers and set debug logging
function simple_fmi3GetVersion()
    global STRING_VERSION_3_0
    return pointer(STRING_VERSION_3_0)
end

function simple_fmi3SetDebugLogging(
    _instance::fmi3Instance,
    loggingOn::fmi3Boolean,
    nCategories::Csize_t,
    categories::Ptr{fmi3String},
)
    instance = dereferenceInstance(_instance)

    instance.loggingOn = (loggingOn != fmi3False)
    # ToDo: categories (arguments)

    return fmi3StatusOK
end

# creation and destruction of FMU instances
function simple_fmi3Instantiate(
    instanceName::fmi3String,
    type::fmi3Type,
    visible::fmi3Boolean,
    loggingOn::fmi3Boolean,
    instanceEnvironment::fmi3InstanceEnvironment,
    logMessage::Ptr{Cvoid},
)
    global FMIBUILD_FMU

    instance = FMU3Instance(FMIBUILD_FMU)
    instance.instanceEnvironment = FMU3InstanceEnvironment()
    instance.callbackLogMessage = logMessage
    instance.callbackInstanceEnvironment = instanceEnvironment
    instance.loggingOn = (loggingOn != fmi3False)
    instance.visible = (visible != fmi3False)
    instance.instanceName = unsafe_string(instanceName)
    instance.type = type

    # event flags, used by FMIBase for event handling (e.g. internal CS simulation)
    instance.rootsFound =
        zeros(fmi3Int32, FMIBUILD_FMU.modelDescription.numberOfEventIndicators)
    instance.stateEvent = fmi3False
    instance.timeEvent = fmi3False
    instance.stepEvent = fmi3False

    instance.addr = pointer_from_objref(instance)
    push!(FMIBUILD_FMU.instances, instance)

    reset(instance)

    return instance.addr
end

function simple_fmi3InstantiateModelExchange(
    instanceName::fmi3String,
    instantiationToken::fmi3String,
    resourcePath::fmi3String,
    visible::fmi3Boolean,
    loggingOn::fmi3Boolean,
    instanceEnvironment::fmi3InstanceEnvironment,
    logMessage::Ptr{Cvoid},
)
    return simple_fmi3Instantiate(
        instanceName,
        fmi3TypeModelExchange,
        visible,
        loggingOn,
        instanceEnvironment,
        logMessage,
    )
end

function simple_fmi3InstantiateCoSimulation(
    instanceName::fmi3String,
    instantiationToken::fmi3String,
    resourcePath::fmi3String,
    visible::fmi3Boolean,
    loggingOn::fmi3Boolean,
    eventModeUsed::fmi3Boolean,
    earlyReturnAllowed::fmi3Boolean,
    requiredIntermediateVariables::Ptr{fmi3ValueReference},
    nRequiredIntermediateVariables::Csize_t,
    instanceEnvironment::fmi3InstanceEnvironment,
    logMessage::Ptr{Cvoid},
    intermediateUpdate::Ptr{Cvoid},
)
    return simple_fmi3Instantiate(
        instanceName,
        fmi3TypeCoSimulation,
        visible,
        loggingOn,
        instanceEnvironment,
        logMessage,
    )
end

function embedded_fmi3InstantiateModelExchange(
    instanceName::fmi3String,
    instantiationToken::fmi3String,
    resourcePath::fmi3String,
    visible::fmi3Boolean,
    loggingOn::fmi3Boolean,
    instanceEnvironment::fmi3InstanceEnvironment,
    logMessage::Ptr{Cvoid},
)
    global FMIBUILD_FMU

    instance = FMU3Instance(FMIBUILD_FMU)
    instance.instanceEnvironment = FMU3InstanceEnvironment()
    instance.callbackLogMessage = logMessage
    instance.callbackInstanceEnvironment = instanceEnvironment
    instance.loggingOn = (loggingOn != fmi3False)
    instance.visible = (visible != fmi3False)
    instance.instanceName = unsafe_string(instanceName)
    instance.type = fmi3TypeModelExchange

    instance.addr = FMICore.fmi3InstantiateModelExchange(
        FMIBUILD_FMU.cFunctionPtrs["EMBEDDED_fmi3InstantiateModelExchange"],
        instanceName,
        instantiationToken,
        resourcePath,
        visible,
        loggingOn,
        instanceEnvironment,
        logMessage,
    )
    push!(FMIBUILD_FMU.instances, instance)

    return instance.addr
end

function embedded_fmi3InstantiateCoSimulation(
    instanceName::fmi3String,
    instantiationToken::fmi3String,
    resourcePath::fmi3String,
    visible::fmi3Boolean,
    loggingOn::fmi3Boolean,
    eventModeUsed::fmi3Boolean,
    earlyReturnAllowed::fmi3Boolean,
    requiredIntermediateVariables::Ptr{fmi3ValueReference},
    nRequiredIntermediateVariables::Csize_t,
    instanceEnvironment::fmi3InstanceEnvironment,
    logMessage::Ptr{Cvoid},
    intermediateUpdate::Ptr{Cvoid},
)
    global FMIBUILD_FMU

    instance = FMU3Instance(FMIBUILD_FMU)
    instance.instanceEnvironment = FMU3InstanceEnvironment()
    instance.callbackLogMessage = logMessage
    instance.callbackInstanceEnvironment = instanceEnvironment
    instance.loggingOn = (loggingOn != fmi3False)
    instance.visible = (visible != fmi3False)
    instance.instanceName = unsafe_string(instanceName)
    instance.type = fmi3TypeCoSimulation

    instance.addr = FMICore.fmi3InstantiateCoSimulation(
        FMIBUILD_FMU.cFunctionPtrs["EMBEDDED_fmi3InstantiateCoSimulation"],
        instanceName,
        instantiationToken,
        resourcePath,
        visible,
        loggingOn,
        eventModeUsed,
        earlyReturnAllowed,
        requiredIntermediateVariables,
        nRequiredIntermediateVariables,
        instanceEnvironment,
        logMessage,
        intermediateUpdate,
    )
    push!(FMIBUILD_FMU.instances, instance)

    return instance.addr
end

function simple_fmi3FreeInstance(_instance::fmi3Instance)
    instance = dereferenceInstance(_instance)

    if !isnothing(instance)
        global FMIBUILD_FMU
        filter!(inst -> inst.addr != instance.addr, FMIBUILD_FMU.instances)
    end

    nothing
end

function embedded_fmi3FreeInstance(_instance::fmi3Instance)
    instance = dereferenceInstance(_instance)

    if !isnothing(instance)
        global FMIBUILD_FMU
        FMICore.fmi3FreeInstance(
            FMIBUILD_FMU.cFunctionPtrs["EMBEDDED_fmi3FreeInstance"],
            instance.addr,
        )
        filter!(inst -> inst.addr != instance.addr, FMIBUILD_FMU.instances)
    end

    nothing
end

# enter and exit initialization mode, enter event mode, terminate and reset
function simple_fmi3EnterInitializationMode(
    _instance::fmi3Instance,
    toleranceDefined::fmi3Boolean,
    tolerance::fmi3Float64,
    startTime::fmi3Float64,
    stopTimeDefined::fmi3Boolean,
    stopTime::fmi3Float64,
)
    instance = dereferenceInstance(_instance)

    instance.state = fmi3InstanceStateInitializationMode
    instance.t = startTime

    evaluate(instance)

    return fmi3StatusOK
end

function simple_fmi3ExitInitializationMode(_instance::fmi3Instance)
    instance = dereferenceInstance(_instance)

    # [Note] values set before or during initialization are kept, dependent values are updated
    evaluate(instance)

    if instance.type == fmi3TypeCoSimulation
        instance.state = fmi3InstanceStateStepMode
    else
        instance.state = fmi3InstanceStateEventMode
    end

    return fmi3StatusOK
end

function simple_fmi3EnterEventMode(_instance::fmi3Instance)
    instance = dereferenceInstance(_instance)

    instance.state = fmi3InstanceStateEventMode

    return fmi3StatusOK
end

function simple_fmi3Terminate(_instance::fmi3Instance)
    instance = dereferenceInstance(_instance)

    instance.state = fmi3InstanceStateTerminated

    return fmi3StatusOK
end

function simple_fmi3Reset(_instance::fmi3Instance)
    instance = dereferenceInstance(_instance)

    reset(instance)
    instance.state = fmi3InstanceStateInstantiated
    instance.problem = nothing

    return fmi3StatusOK
end

# getting and setting variable values
function simple_fmi3GetFloat64(
    _instance::fmi3Instance,
    _vr::Ptr{fmi3ValueReference},
    nvr::Csize_t,
    _values::Ptr{fmi3Float64},
    nValues::Csize_t,
)
    instance = dereferenceInstance(_instance)
    return getValues(instance, _vr, nvr, _values, "fmi3GetFloat64")
end

function simple_fmi3GetInt32(
    _instance::fmi3Instance,
    _vr::Ptr{fmi3ValueReference},
    nvr::Csize_t,
    _values::Ptr{fmi3Int32},
    nValues::Csize_t,
)
    instance = dereferenceInstance(_instance)
    return getValues(instance, _vr, nvr, _values, "fmi3GetInt32")
end

function simple_fmi3GetInt64(
    _instance::fmi3Instance,
    _vr::Ptr{fmi3ValueReference},
    nvr::Csize_t,
    _values::Ptr{fmi3Int64},
    nValues::Csize_t,
)
    instance = dereferenceInstance(_instance)
    return getValues(instance, _vr, nvr, _values, "fmi3GetInt64")
end

function simple_fmi3GetBoolean(
    _instance::fmi3Instance,
    _vr::Ptr{fmi3ValueReference},
    nvr::Csize_t,
    _values::Ptr{fmi3Boolean},
    nValues::Csize_t,
)
    instance = dereferenceInstance(_instance)
    return getValues(instance, _vr, nvr, _values, "fmi3GetBoolean")
end

function simple_fmi3SetFloat64(
    _instance::fmi3Instance,
    _vr::Ptr{fmi3ValueReference},
    nvr::Csize_t,
    _values::Ptr{fmi3Float64},
    nValues::Csize_t,
)
    instance = dereferenceInstance(_instance)
    return setValues(instance, _vr, nvr, _values, "fmi3SetFloat64")
end

function simple_fmi3SetInt32(
    _instance::fmi3Instance,
    _vr::Ptr{fmi3ValueReference},
    nvr::Csize_t,
    _values::Ptr{fmi3Int32},
    nValues::Csize_t,
)
    instance = dereferenceInstance(_instance)
    return setValues(instance, _vr, nvr, _values, "fmi3SetInt32")
end

function simple_fmi3SetInt64(
    _instance::fmi3Instance,
    _vr::Ptr{fmi3ValueReference},
    nvr::Csize_t,
    _values::Ptr{fmi3Int64},
    nValues::Csize_t,
)
    instance = dereferenceInstance(_instance)
    return setValues(instance, _vr, nvr, _values, "fmi3SetInt64")
end

function simple_fmi3SetBoolean(
    _instance::fmi3Instance,
    _vr::Ptr{fmi3ValueReference},
    nvr::Csize_t,
    _values::Ptr{fmi3Boolean},
    nValues::Csize_t,
)
    instance = dereferenceInstance(_instance)
    return setValues(instance, _vr, nvr, _values, "fmi3SetBoolean")
end

# discrete states
function simple_fmi3UpdateDiscreteStates(
    _instance::fmi3Instance,
    _discreteStatesNeedUpdate::Ptr{fmi3Boolean},
    _terminateSimulation::Ptr{fmi3Boolean},
    _nominalsOfContinuousStatesChanged::Ptr{fmi3Boolean},
    _valuesOfContinuousStatesChanged::Ptr{fmi3Boolean},
    _nextEventTimeDefined::Ptr{fmi3Boolean},
    _nextEventTime::Ptr{fmi3Float64},
)
    instance = dereferenceInstance(_instance)

    if instance.state != fmi3InstanceStateEventMode
        logError(
            instance,
            "fmi3UpdateDiscreteStates must be called in event mode, mode is `$(instance.state)`!",
        )
        return fmi3StatusError
    end

    evaluate(instance, true)

    # reset before writing the outputs, the importer may pass the instance buffers (if used in the same process)
    valuesOfContinuousStatesChanged = instance.valuesOfContinuousStatesChanged
    instance.valuesOfContinuousStatesChanged = fmi3False

    unsafe_store!(_discreteStatesNeedUpdate, fmi3False)
    unsafe_store!(_terminateSimulation, fmi3False) # [ToDo]
    unsafe_store!(_nominalsOfContinuousStatesChanged, fmi3False) # [ToDo]
    unsafe_store!(_valuesOfContinuousStatesChanged, valuesOfContinuousStatesChanged)
    unsafe_store!(_nextEventTimeDefined, fmi3False) # [ToDo] support for time events
    unsafe_store!(_nextEventTime, fmi3Float64(0.0))

    return fmi3StatusOK
end

# Model Exchange
function simple_fmi3EnterContinuousTimeMode(_instance::fmi3Instance)
    instance = dereferenceInstance(_instance)

    instance.state = fmi3InstanceStateContinuousTimeMode

    return fmi3StatusOK
end

function simple_fmi3CompletedIntegratorStep(
    _instance::fmi3Instance,
    noSetFMUStatePriorToCurrentPoint::fmi3Boolean,
    _enterEventMode::Ptr{fmi3Boolean},
    _terminateSimulation::Ptr{fmi3Boolean},
)
    unsafe_store!(_enterEventMode, fmi3False)
    unsafe_store!(_terminateSimulation, fmi3False)

    return fmi3StatusOK
end

function simple_fmi3SetTime(_instance::fmi3Instance, time::fmi3Float64)
    instance = dereferenceInstance(_instance)

    instance.t = time

    evaluate(instance)

    return fmi3StatusOK
end

function simple_fmi3SetContinuousStates(
    _instance::fmi3Instance,
    _x::Ptr{fmi3Float64},
    nx::Csize_t,
)
    instance = dereferenceInstance(_instance)
    vrs = instance.fmu.modelDescription.stateValueReferences

    if nx != length(vrs)
        logWarning(
            instance,
            "fmi3SetContinuousStates: Model has $(length(vrs)) states, but `nContinuousStates`=$(nx).",
        )
        return fmi3StatusWarning
    end

    for i = 1:nx
        instance.values[vrs[i]] = toInstanceValue(unsafe_load(_x, i))
    end

    evaluate(instance)

    return fmi3StatusOK
end

function simple_fmi3GetContinuousStateDerivatives(
    _instance::fmi3Instance,
    _derivatives::Ptr{fmi3Float64},
    nx::Csize_t,
)
    instance = dereferenceInstance(_instance)
    vrs = instance.fmu.modelDescription.derivativeValueReferences

    if nx != length(vrs)
        logWarning(
            instance,
            "fmi3GetContinuousStateDerivatives: Model has $(length(vrs)) states, but `nContinuousStates`=$(nx).",
        )
        return fmi3StatusWarning
    end

    for i = 1:nx
        unsafe_store!(_derivatives, fmi3Float64(instance.values[vrs[i]]), i)
    end

    return fmi3StatusOK
end

function simple_fmi3GetEventIndicators(
    _instance::fmi3Instance,
    _eventIndicators::Ptr{fmi3Float64},
    ni::Csize_t,
)
    instance = dereferenceInstance(_instance)

    numberOfEventIndicators = instance.fmu.modelDescription.numberOfEventIndicators
    if ni != numberOfEventIndicators
        logWarning(
            instance,
            "fmi3GetEventIndicators: Model has $(numberOfEventIndicators) event indicators, but `nEventIndicators`=$(ni).",
        )
        return fmi3StatusWarning
    end

    xc, ẋc, xd, u, y, p = extractValues(instance)
    instance.z = FMU_FCT_EVENT(instance.t, xc, ẋc, xd, u, p)
    applyEventIndicators(instance)

    for i = 1:ni
        unsafe_store!(_eventIndicators, fmi3Float64(instance.z[i]), i)
    end

    return fmi3StatusOK
end

function simple_fmi3GetContinuousStates(
    _instance::fmi3Instance,
    _x::Ptr{fmi3Float64},
    nx::Csize_t,
)
    instance = dereferenceInstance(_instance)
    vrs = instance.fmu.modelDescription.stateValueReferences

    if nx != length(vrs)
        logWarning(
            instance,
            "fmi3GetContinuousStates: Model has $(length(vrs)) states, but `nContinuousStates`=$(nx).",
        )
        return fmi3StatusWarning
    end

    for i = 1:nx
        unsafe_store!(_x, fmi3Float64(instance.values[vrs[i]]), i)
    end

    return fmi3StatusOK
end

function simple_fmi3GetNominalsOfContinuousStates(
    _instance::fmi3Instance,
    _x_nominal::Ptr{fmi3Float64},
    nx::Csize_t,
)
    instance = dereferenceInstance(_instance)
    numberOfStates = length(instance.fmu.modelDescription.stateValueReferences)

    if nx != numberOfStates
        logWarning(
            instance,
            "fmi3GetNominalsOfContinuousStates: Model has $(numberOfStates) states, but `nContinuousStates`=$(nx).",
        )
        return fmi3StatusWarning
    end

    for i = 1:nx
        unsafe_store!(_x_nominal, fmi3Float64(1.0), i)
    end

    return fmi3StatusOK
end

function simple_fmi3GetNumberOfEventIndicators(
    _instance::fmi3Instance,
    _nEventIndicators::Ptr{Csize_t},
)
    instance = dereferenceInstance(_instance)

    unsafe_store!(
        _nEventIndicators,
        Csize_t(instance.fmu.modelDescription.numberOfEventIndicators),
    )

    return fmi3StatusOK
end

function simple_fmi3GetNumberOfContinuousStates(
    _instance::fmi3Instance,
    _nContinuousStates::Ptr{Csize_t},
)
    instance = dereferenceInstance(_instance)

    unsafe_store!(
        _nContinuousStates,
        Csize_t(length(instance.fmu.modelDescription.stateValueReferences)),
    )

    return fmi3StatusOK
end

# Co-Simulation
function simple_fmi3EnterStepMode(_instance::fmi3Instance)
    instance = dereferenceInstance(_instance)

    instance.state = fmi3InstanceStateStepMode

    return fmi3StatusOK
end

function simple_fmi3DoStep(
    _instance::fmi3Instance,
    currentCommunicationPoint::fmi3Float64,
    communicationStepSize::fmi3Float64,
    noSetFMUStatePriorToCurrentPoint::fmi3Boolean,
    _eventHandlingNeeded::Ptr{fmi3Boolean},
    _terminateSimulation::Ptr{fmi3Boolean},
    _earlyReturn::Ptr{fmi3Boolean},
    _lastSuccessfulTime::Ptr{fmi3Float64},
)
    instance = dereferenceInstance(_instance)

    unsafe_store!(_eventHandlingNeeded, fmi3False)
    unsafe_store!(_terminateSimulation, fmi3False)
    unsafe_store!(_earlyReturn, fmi3False)
    unsafe_store!(_lastSuccessfulTime, instance.t)

    if communicationStepSize < 0.0
        logError(instance, "fmi3DoStep: communicationStepSize must be non-negative.")
        return fmi3StatusError
    end

    if !isapprox(currentCommunicationPoint, instance.t)
        logWarning(
            instance,
            "fmi3DoStep: currentCommunicationPoint=$(currentCommunicationPoint), but current FMU instance time is $(instance.t).",
        )
    end

    if isnothing(instance.problem) # first step
        try
            _enable_cs_export(instance.fmu)
        catch e
            logError(instance, "fmi3DoStep: $(sprint(showerror, e))")
            return fmi3StatusError
        end
        prepareCoSimulation(instance)
    end

    # [Note] states may have been set by the importer since the last step
    xc, _, _, _, _, _ = extractValues(instance)
    x0 = fmi3Float64.(xc)
    tspan = (currentCommunicationPoint, currentCommunicationPoint + communicationStepSize)
    solveKwargs = Dict{Symbol,Any}()
    tspan = FMIBase.setupSolver!(instance.fmu, tspan, solveKwargs)

    solver = FMU_FCT_SOLVER()
    @assert !isnothing(solver) "For CS-FMUs, you need to overwrite `FMU_FCT_SOLVER()` to specify a solver!"

    # ToDo: this should be a little more light weight, check what actually
    # needs to be done for every doStep, and which parts can be reused.
    instance.problem = FMIBase.setupODEProblem(instance, x0, tspan)
    instance.state = fmi3InstanceStateContinuousTimeMode
    instance.type = fmi3TypeModelExchange
    states = try
        FMIBase.SciMLBase.solve(
            instance.problem,
            solver;
            callback = FMIBase.SciMLBase.CallbackSet(instance.callback...),
            solveKwargs...,
        )
    finally
        instance.type = fmi3TypeCoSimulation
        instance.state = fmi3InstanceStateStepMode
    end

    instance.t = states.t[end]
    instance.x = fmi3Float64.(states.u[end])

    # overwrite with new values
    _, ẋc, xd, u, y, p = extractValues(instance)
    applyValues(instance, instance.x, ẋc, xd, u, y, p)
    evaluate(instance)

    unsafe_store!(_lastSuccessfulTime, instance.t)

    return fmi3StatusOK
end

"""
    createFMU3Simple(modelName=""; kwargs...)

Create an FMI 3 FMU from the model functions, see `createFMU2Simple` for the arguments.

    initializationFct           # () -> (t, xc, ẋc, xd, u, p)
    evaluationFct               # (t, xc, ẋc, xd, u, p, event) -> (xc, ẋc, xd, p)
    outputFct                   # (t, xc, ẋc, xd, u, p) -> y
    eventFct                    # (t, xc, ẋc, xd, u, p) -> e
    solverFct                   # () -> AbstractODEAlgorithm
"""
function createFMU3Simple(
    modelName::String = "";
    initializationFct = DEFAULT_FMU_FCT_INIT,
    evaluationFct = DEFAULT_FMU_FCT_EVALUATE,
    outputFct = DEFAULT_FMU_FCT_OUTPUT,
    eventFct = DEFAULT_FMU_FCT_EVENT,
    solverFct = DEFAULT_FMU_FCT_SOLVER,
    type = fmi3TypeModelExchange,
)

    global FMIBUILD_FMU

    global FMU_FCT_INIT
    global FMU_FCT_EVALUATE
    global FMU_FCT_OUTPUT
    global FMU_FCT_EVENT
    global FMU_FCT_SOLVER

    global FMU_NUM_STATES
    global FMU_NUM_DISCRETE_STATES
    global FMU_NUM_OUTPUTS
    global FMU_NUM_INPUTS
    global FMU_NUM_EVENTS
    global FMU_NUM_PARAMETERS

    FMIBUILD_FMU = createFMU3(modelName; type = type)

    if type == fmi3TypeCoSimulation
        _enable_cs_export(FMIBUILD_FMU)
    end

    FMU_FCT_INIT = isnothing(initializationFct) ? DEFAULT_FMU_FCT_INIT : initializationFct
    FMU_FCT_EVALUATE = isnothing(evaluationFct) ? DEFAULT_FMU_FCT_EVALUATE : evaluationFct
    FMU_FCT_OUTPUT = isnothing(outputFct) ? DEFAULT_FMU_FCT_OUTPUT : outputFct
    FMU_FCT_EVENT = isnothing(eventFct) ? DEFAULT_FMU_FCT_EVENT : eventFct
    FMU_FCT_SOLVER = isnothing(solverFct) ? DEFAULT_FMU_FCT_SOLVER : solverFct

    t, xc, ẋc, xd, u, p = FMU_FCT_INIT()
    y = FMU_FCT_OUTPUT(t, xc, ẋc, xd, u, p)
    e = FMU_FCT_EVENT(t, xc, ẋc, xd, u, p)

    FMU_NUM_STATES = length(xc)
    FMU_NUM_DISCRETE_STATES = length(xd)
    FMU_NUM_OUTPUTS = length(y)
    FMU_NUM_INPUTS = length(u)
    FMU_NUM_EVENTS = length(e)
    FMU_NUM_PARAMETERS = length(p)

    setFctGetVersion(FMIBUILD_FMU, simple_fmi3GetVersion)
    setFctSetDebugLogging(FMIBUILD_FMU, simple_fmi3SetDebugLogging)
    setFctInstantiateModelExchange(FMIBUILD_FMU, simple_fmi3InstantiateModelExchange)
    setFctInstantiateCoSimulation(FMIBUILD_FMU, simple_fmi3InstantiateCoSimulation)
    setFctFreeInstance(FMIBUILD_FMU, simple_fmi3FreeInstance)
    setFctEnterInitializationMode(FMIBUILD_FMU, simple_fmi3EnterInitializationMode)
    setFctExitInitializationMode(FMIBUILD_FMU, simple_fmi3ExitInitializationMode)
    setFctEnterEventMode(FMIBUILD_FMU, simple_fmi3EnterEventMode)
    setFctTerminate(FMIBUILD_FMU, simple_fmi3Terminate)
    setFctReset(FMIBUILD_FMU, simple_fmi3Reset)
    setFctGetFloat64(FMIBUILD_FMU, simple_fmi3GetFloat64)
    setFctGetInt32(FMIBUILD_FMU, simple_fmi3GetInt32)
    setFctGetInt64(FMIBUILD_FMU, simple_fmi3GetInt64)
    setFctGetBoolean(FMIBUILD_FMU, simple_fmi3GetBoolean)
    setFctSetFloat64(FMIBUILD_FMU, simple_fmi3SetFloat64)
    setFctSetInt32(FMIBUILD_FMU, simple_fmi3SetInt32)
    setFctSetInt64(FMIBUILD_FMU, simple_fmi3SetInt64)
    setFctSetBoolean(FMIBUILD_FMU, simple_fmi3SetBoolean)
    setFctUpdateDiscreteStates(FMIBUILD_FMU, simple_fmi3UpdateDiscreteStates)

    # Model Exchange
    setFctEnterContinuousTimeMode(FMIBUILD_FMU, simple_fmi3EnterContinuousTimeMode)
    setFctCompletedIntegratorStep(FMIBUILD_FMU, simple_fmi3CompletedIntegratorStep)
    setFctSetTime(FMIBUILD_FMU, simple_fmi3SetTime)
    setFctSetContinuousStates(FMIBUILD_FMU, simple_fmi3SetContinuousStates)
    setFctGetContinuousStateDerivatives(
        FMIBUILD_FMU,
        simple_fmi3GetContinuousStateDerivatives,
    )
    setFctGetEventIndicators(FMIBUILD_FMU, simple_fmi3GetEventIndicators)
    setFctGetContinuousStates(FMIBUILD_FMU, simple_fmi3GetContinuousStates)
    setFctGetNominalsOfContinuousStates(
        FMIBUILD_FMU,
        simple_fmi3GetNominalsOfContinuousStates,
    )
    setFctGetNumberOfEventIndicators(FMIBUILD_FMU, simple_fmi3GetNumberOfEventIndicators)
    setFctGetNumberOfContinuousStates(FMIBUILD_FMU, simple_fmi3GetNumberOfContinuousStates)

    # Co-Simulation
    setFctEnterStepMode(FMIBUILD_FMU, simple_fmi3EnterStepMode)
    setFctDoStep(FMIBUILD_FMU, simple_fmi3DoStep)

    # not supported, return `fmi3Error`
    for (setFct, name) in (
        (setFctGetFloat32, "fmi3GetFloat32"),
        (setFctGetInt8, "fmi3GetInt8"),
        (setFctGetUInt8, "fmi3GetUInt8"),
        (setFctGetInt16, "fmi3GetInt16"),
        (setFctGetUInt16, "fmi3GetUInt16"),
        (setFctGetUInt32, "fmi3GetUInt32"),
        (setFctGetUInt64, "fmi3GetUInt64"),
        (setFctGetString, "fmi3GetString"),
        (setFctGetBinary, "fmi3GetBinary"),
        (setFctSetFloat32, "fmi3SetFloat32"),
        (setFctSetInt8, "fmi3SetInt8"),
        (setFctSetUInt8, "fmi3SetUInt8"),
        (setFctSetInt16, "fmi3SetInt16"),
        (setFctSetUInt16, "fmi3SetUInt16"),
        (setFctSetUInt32, "fmi3SetUInt32"),
        (setFctSetUInt64, "fmi3SetUInt64"),
        (setFctSetString, "fmi3SetString"),
        (setFctSetBinary, "fmi3SetBinary"),
        (setFctGetNumberOfVariableDependencies, "fmi3GetNumberOfVariableDependencies"),
        (setFctGetVariableDependencies, "fmi3GetVariableDependencies"),
        (setFctGetFMUState, "fmi3GetFMUState"),
        (setFctSetFMUState, "fmi3SetFMUState"),
        (setFctFreeFMUState, "fmi3FreeFMUState"),
        (setFctSerializedFMUStateSize, "fmi3SerializedFMUStateSize"),
        (setFctSerializeFMUState, "fmi3SerializeFMUState"),
        (setFctDeSerializeFMUState, "fmi3DeserializeFMUState"),
        (setFctGetDirectionalDerivative, "fmi3GetDirectionalDerivative"),
        (setFctGetAdjointDerivative, "fmi3GetAdjointDerivative"),
        (setFctEnterConfigurationMode, "fmi3EnterConfigurationMode"),
        (setFctExitConfigurationMode, "fmi3ExitConfigurationMode"),
        (setFctEvaluateDiscreteStates, "fmi3EvaluateDiscreteStates"),
        (setFctGetOutputDerivatives, "fmi3GetOutputDerivatives"),
    )
        setFct(FMIBUILD_FMU, simple_fmi3NotSupported(name))
    end

    return FMIBUILD_FMU
end
export createFMU3Simple
