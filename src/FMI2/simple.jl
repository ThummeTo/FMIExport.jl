#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

#import FMICore: fmi2ComponentStateEventMode, fmi2ComponentStateInstantiated, fmi2ComponentStateContinuousTimeMode
#import FMICore: logInfo, logWarning, logError

FMU_NUM_STATES = 0
# FMU_NUM_DERIVATIVES = FMU_NUM_STATES
FMU_NUM_DISCRETE_STATES = 0
FMU_NUM_OUTPUTS = 0
FMU_NUM_INPUTS = 0
FMU_NUM_EVENTS = 0
FMU_NUM_PARAMETERS = 0

FMU_FCT_INIT = function ()
    return ([], [], [], [], [], [])
end
FMU_FCT_EVALUATE = function (t, xc, ẋc, xd, u, p, eventMode)
    return ([], [], [], [])
end
FMU_FCT_OUTPUT = function (t, xc, ẋc, xd, u, p)
    return []
end
FMU_FCT_EVENT = function (t, xc, ẋc, xd, u, p)
    return []
end
FMU_FCT_SOLVER = function ()
    return nothing
end

##############

function dereferenceInstance(address::fmi2Component)
    global FMIBUILD_FMU
    for component in FMIBUILD_FMU.components
        if component.addr == address
            return component
        end
    end

    @warn "Unknown instance at $(address)."
    return nothing
end

##############

function reset(_component::fmi2Component)
    component = dereferenceInstance(_component)

    component.t, xc, ẋc, xd, u, p = FMU_FCT_INIT()
    component.z = FMU_FCT_EVENT(component.t, xc, ẋc, xd, u, p)
    y = FMU_FCT_OUTPUT(component.t, xc, ẋc, xd, u, p)

    applyValues(component.addr, xc, ẋc, xd, u, y, p)
end

function evaluate(_component::fmi2Component, eventMode=false)
    component = dereferenceInstance(_component)

    # eventMode = component.state == fmi2ComponentStateEventMode

    xc, ẋc, xd, u, y, p = extractValues(_component)

    tmp_xc, ẋc, tmp_xd, p = FMU_FCT_EVALUATE(component.t, xc, ẋc, xd, u, p, eventMode)

    if eventMode # overwrite state vector allowed
        component.eventInfo.valuesOfContinuousStatesChanged =
            (xc != tmp_xc ? fmi2True : component.eventInfo.valuesOfContinuousStatesChanged)
        #component.eventInfo.newDiscreteStatesNeeded =         (xd != tmp_xd ? fmi2True : fmi2False)

        xc = tmp_xc
        xd = tmp_xd
    else
        # if xc != tmp_xc
        #     logError(component, "FMU_FCT_EVALUATE changes the systems continuous state while not being in event-mode, this is not allowed!")
        # end

        if xd != tmp_xd
            logError(
                component,
                "FMU_FCT_EVALUATE changes the systems discrete state while not being in event-mode, this is not allowed!",
            )
        end
    end

    y = FMU_FCT_OUTPUT(component.t, xc, ẋc, xd, u, p)
    z_new = FMU_FCT_EVENT(component.t, xc, ẋc, xd, u, p)

    applyValues(_component, xc, ẋc, xd, u, y, p)

    # event triggering

    if (component.z_prev != nothing) && (sign.(z_new) != sign.(component.z_prev))
        component.z_prev = z_new
        component.z = z_new
    else
        component.z_prev = component.z
        component.z = z_new
    end
end

# ToDo: this function should be more efficient
function applyValues(_component::fmi2Component, xc, ẋc, xd, u, y, p)
    component = dereferenceInstance(_component)

    for i = 1:length(FMIBUILD_FMU.modelDescription.stateValueReferences)
        vr = FMIBUILD_FMU.modelDescription.stateValueReferences[i]
        component.values[vr] = xc[i]
    end

    for i = 1:length(FMIBUILD_FMU.modelDescription.derivativeValueReferences)
        vr = FMIBUILD_FMU.modelDescription.derivativeValueReferences[i]
        component.values[vr] = ẋc[i]
    end

    for i = 1:length(FMIBUILD_FMU.modelDescription.discreteStateValueReferences)
        vr = FMIBUILD_FMU.modelDescription.discreteStateValueReferences[i]
        component.values[vr] = xd[i]
    end

    for i = 1:length(FMIBUILD_FMU.modelDescription.inputValueReferences)
        vr = FMIBUILD_FMU.modelDescription.inputValueReferences[i]
        component.values[vr] = u[i]
    end

    for i = 1:length(FMIBUILD_FMU.modelDescription.outputValueReferences)
        vr = FMIBUILD_FMU.modelDescription.outputValueReferences[i]
        component.values[vr] = y[i]
    end

    for i = 1:length(FMIBUILD_FMU.modelDescription.parameterValueReferences)
        vr = FMIBUILD_FMU.modelDescription.parameterValueReferences[i]
        component.values[vr] = p[i]
    end

    nothing
end

# ToDo: this function should be more efficient
function extractValues(_component::fmi2Component)
    component = dereferenceInstance(_component)

    xcs = collect(
        component.values[vr] for vr in component.fmu.modelDescription.stateValueReferences
    )
    ẋcs = collect(
        component.values[vr] for
        vr in component.fmu.modelDescription.derivativeValueReferences
    )
    xds = collect(
        component.values[vr] for
        vr in component.fmu.modelDescription.discreteStateValueReferences
    )
    us = collect(
        component.values[vr] for vr in component.fmu.modelDescription.inputValueReferences
    )
    ys = collect(
        component.values[vr] for vr in component.fmu.modelDescription.outputValueReferences
    )
    ps = collect(
        component.values[vr] for
        vr in component.fmu.modelDescription.parameterValueReferences
    )

    return xcs, ẋcs, xds, us, ys, ps
end

const STRING_TYPES_PLATFORM_DEFAULT = "default"
const STRING_VERSION_2_0 = "2.0"

# 2.1.4
function simple_fmi2GetTypesPlatform()
    global STRING_TYPES_PLATFORM_DEFAULT
    return pointer(STRING_TYPES_PLATFORM_DEFAULT)
end

function simple_fmi2GetVersion()
    global STRING_VERSION_2_0
    return pointer(STRING_VERSION_2_0)
end

# 2.1.5
function simple_fmi2Instantiate(
    instanceName::fmi2String,
    fmuType::fmi2Type,
    fmuGUID::fmi2String,
    fmuResourceLocation::fmi2String,
    functions::Ptr{fmi2CallbackFunctions},
    visible::fmi2Boolean,
    loggingOn::fmi2Boolean,
)

    global FMIBUILD_FMU

    component = FMU2Component(FMIBUILD_FMU)
    component.loggingOn = (loggingOn == fmi2True)
    component.callbackFunctions = unsafe_load(functions)
    component.instanceName = unsafe_string(instanceName)
    component.type = fmuType

    component.addr = pointer_from_objref(component)
    push!(FMIBUILD_FMU.components, component)

    reset(component.addr)

    return component.addr
end

function embedded_fmi2Instantiate(
    instanceName::fmi2String,
    fmuType::fmi2Type,
    fmuGUID::fmi2String,
    fmuResourceLocation::fmi2String,
    functions::Ptr{fmi2CallbackFunctions},
    visible::fmi2Boolean,
    loggingOn::fmi2Boolean,
)

    global FMIBUILD_FMU

    component = FMU2Component(FMIBUILD_FMU)
    component.loggingOn = (loggingOn == fmi2True ? true : false)
    component.callbackFunctions = unsafe_load(functions)
    component.instanceName = unsafe_string(instanceName)
    component.type = fmuType

    component.addr = FMICore.fmi2Instantiate(
        FMIBUILD_FMU.cFunctionPtrs["EMBEDDED_fmi2Instantiate"],
        instanceName,
        fmuType,
        fmuGUID,
        fmuResourceLocation,
        functions,
        visible,
        loggingOn,
    )
    push!(FMIBUILD_FMU.components, component)

    return component.addr
end

function simple_fmi2FreeInstance(_component::fmi2Component)
    component = dereferenceInstance(_component)

    if component != nothing

        global FMIBUILD_FMU
        for i = 1:length(FMIBUILD_FMU.components)
            if FMIBUILD_FMU.components[i].addr == component.addr
                deleteat!(FMIBUILD_FMU.components, i)
                break
            end
        end

    end

    nothing
end

function embedded_fmi2FreeInstance(_component::fmi2Component)

    component = dereferenceInstance(_component)

    if component != nothing

        global FMIBUILD_FMU
        for i = 1:length(FMIBUILD_FMU.components)
            if FMIBUILD_FMU.components[i].addr == component.addr
                FMICore.fmi2FreeInstance!(
                    FMIBUILD_FMU.cFunctionPtrs["EMBEDDED_fmi2FreeInstance"],
                    component.addr,
                )
                deleteat!(FMIBUILD_FMU.components, i)
                break
            end
        end

    end

    nothing
end

function simple_fmi2SetDebugLogging(
    _component::fmi2Component,
    loggingOn::fmi2Boolean,
    nCategories::Csize_t,
    categories::Ptr{fmi2String},
)
    component = dereferenceInstance(_component)

    component.loggingOn = loggingOn
    # ToDo: categories (arguments)

    return fmi2StatusOK
end

const FMIIMPORT_CS_ERROR = "FMIImport required for CS FMU export. Load it first with `using FMIImport`."

_prepare_cs_fmu(args...; kwargs...) = throw(ArgumentError(FMIIMPORT_CS_ERROR))
_enable_cs_export(args...) = throw(ArgumentError(FMIIMPORT_CS_ERROR))

function simple_fmi2SetupExperiment(
    _component::fmi2Component,
    toleranceDefined::fmi2Boolean,
    tolerance::fmi2Real,
    startTime::fmi2Real,
    stopTimeDefined::fmi2Boolean,
    stopTime::fmi2Real,
)
    component = dereferenceInstance(_component)

    # build CS problem 
    t_stop = stopTimeDefined == fmi2True ? stopTime : typemax(fmi2Real)
    tspan = (Float64(startTime), Float64(t_stop))
    toleranceValue = toleranceDefined == fmi2True ? tolerance : nothing

    component, x0 = _prepare_cs_fmu(
        component.fmu,
        component,
        :ME;
        t_start=tspan[1],
        t_stop=tspan[end],
        tolerance=toleranceValue,
        instantiate=false,
        freeInstance=false,
        terminate=false,
        reset=false,
        setup=false,
    )
    #component.t = tspan[1]

    # todo handle t_stop, tspan and toleranceValue

    component.problem = FMIBase.setupODEProblem(component, x0, tspan)

    component.callback = FMIBase.setupCallbacks(
        component,
        fmi2ValueReference[],
        nothing,
        false,
        nothing,
        fmi2ValueReference[],
        nothing,
        tspan[1],
        tspan[end],
        nothing,
    )

    return fmi2StatusOK
end

function simple_fmi2EnterInitializationMode(_component::fmi2Component)
    component = dereferenceInstance(_component)

    component.state = fmi2ComponentStateInitializationMode

    return fmi2StatusOK
end

function simple_fmi2ExitInitializationMode(_component::fmi2Component)
    component = dereferenceInstance(_component)

    component.state = fmi2ComponentStateEventMode

    # get initialization values 
    reset(_component)

    return fmi2StatusOK
end

function simple_fmi2SetRealInputDerivatives(
    _component::fmi2Component,
    _vr::Ptr{fmi2ValueReference},
    nvr::Csize_t,
    _order::Ptr{fmi2Integer},
    _value::Ptr{fmi2Real},
)
    component = dereferenceInstance(_component)

    logWarning(component, "fmi2SetRealInputDerivatives: Not supported by this FMU.")

    return fmi2StatusWarning
end

function simple_fmi2GetRealOutputDerivatives(
    _component::fmi2Component,
    _vr::Ptr{fmi2ValueReference},
    nvr::Csize_t,
    _order::Ptr{fmi2Integer},
    _value::Ptr{fmi2Real},
)
    component = dereferenceInstance(_component)

    logWarning(component, "fmi2GetRealOutputDerivatives: Not supported by this FMU.")

    return fmi2StatusWarning
end

function simple_fmi2DoStep(
    _component::fmi2Component,
    currentCommunicationPoint::fmi2Real,
    communicationStepSize::fmi2Real,
    noSetFMUStatePriorToCurrentPoint::fmi2Boolean,
)
    component = dereferenceInstance(_component)

    if communicationStepSize < 0.0
        logError(component, "fmi2DoStep: communicationStepSize must be non-negative.")
        return fmi2StatusError
    end

    if !isapprox(currentCommunicationPoint, component.t)
        logWarning(
            component,
            "fmi2DoStep: currentCommunicationPoint=$(currentCommunicationPoint), but current FMU instance time is $(component.t).",
        )
    end

    if isnothing(component.x) || isnothing(component.problem)
        logWarning(
            component,
            "fmi2DoStep: Called without proper fmi2SetupExperiment, trying to set up experiment automatically.",
        )
        status = simple_fmi2SetupExperiment(
            _component,
            fmi2False,
            0.0,
            currentCommunicationPoint,
            fmi2True,
            currentCommunicationPoint + communicationStepSize,
        )

        if status != fmi2StatusOK
            return status
        end
    end

    x0 = component.x
    tspan = (currentCommunicationPoint, currentCommunicationPoint + communicationStepSize)
    solveKwargs = Dict{Symbol,Any}()
    tspan = FMIBase.setupSolver!(component.fmu, tspan, solveKwargs)

    solver = FMU_FCT_SOLVER()
    @assert !isnothing(solver) "For CS-FMUs, you need to overwrite `FMU_FCT_SOLVER()` to specify a solver!"

    # ToDo: this should be a little more light weight, check what actually
    # needs to be done for every doStep, and which parts can be reused.
    component.problem = FMIBase.setupODEProblem(component, x0, tspan)
    component.state = fmi2ComponentStateContinuousTimeMode
    component.type = fmi2TypeModelExchange
    try
        component.solution.states = FMIBase.SciMLBase.solve(
            component.problem,
            solver,
            callback=FMIBase.SciMLBase.CallbackSet(component.callback...),
            solveKwargs...,
        )
    finally
        component.type = fmi2TypeCoSimulation
    end

    component.t = component.solution.states.t[end]
    component.x = fmi2Real.(component.solution.states.u[end])

    # overwrite with new values
    _, xcdot, xd, u, y, p = extractValues(_component)
    applyValues(_component, component.x, xcdot, xd, u, y, p)
    evaluate(_component)

    return fmi2StatusOK
end

function simple_fmi2CancelStep(_component::fmi2Component)
    component = dereferenceInstance(_component)

    logWarning(component, "fmi2CancelStep: Asynchronous fmi2DoStep is not supported.")

    return fmi2StatusWarning
end

function simple_fmi2GetStatus(
    _component::fmi2Component,
    statusKind::fmi2StatusKind,
    _value::Ptr{fmi2Status},
)
    value = unsafe_wrap(Array{fmi2Status}, _value, 1)
    value[1] = fmi2StatusOK

    return fmi2StatusOK
end

function simple_fmi2GetRealStatus(
    _component::fmi2Component,
    statusKind::fmi2StatusKind,
    _value::Ptr{fmi2Real},
)
    component = dereferenceInstance(_component)
    value = unsafe_wrap(Array{fmi2Real}, _value, 1)

    if statusKind == fmi2StatusKindLastSuccessfulTime
        value[1] = component.t
        return fmi2StatusOK
    end

    logWarning(component, "fmi2GetRealStatus: Unsupported status kind $(statusKind).")
    return fmi2StatusWarning
end

function simple_fmi2GetIntegerStatus(
    _component::fmi2Component,
    statusKind::fmi2StatusKind,
    _value::Ptr{fmi2Integer},
)
    component = dereferenceInstance(_component)

    logWarning(component, "fmi2GetIntegerStatus: Unsupported status kind $(statusKind).")

    return fmi2StatusWarning
end

function simple_fmi2GetBooleanStatus(
    _component::fmi2Component,
    statusKind::fmi2StatusKind,
    _value::Ptr{fmi2Boolean},
)
    component = dereferenceInstance(_component)

    logWarning(component, "fmi2GetBooleanStatus: Unsupported status kind $(statusKind).")

    return fmi2StatusWarning
end

function simple_fmi2GetStringStatus(
    _component::fmi2Component,
    statusKind::fmi2StatusKind,
    _value::Ptr{fmi2String},
)
    component = dereferenceInstance(_component)

    logWarning(component, "fmi2GetStringStatus: Unsupported status kind $(statusKind).")

    return fmi2StatusWarning
end

function simple_fmi2Terminate(_component::fmi2Component)
    component = dereferenceInstance(_component)

    component.state = fmi2ComponentStateTerminated

    return fmi2StatusOK
end

function simple_fmi2Reset(_component::fmi2Component)
    component = dereferenceInstance(_component)

    reset(_component)

    return fmi2StatusOK
end

function simple_fmi2GetReal(
    _component::fmi2Component,
    _vr::Ptr{fmi2ValueReference},
    nvr::Csize_t,
    _value::Ptr{fmi2Real},
)
    component = dereferenceInstance(_component)

    value = unsafe_wrap(Array{fmi2Real}, _value, nvr)
    vr = unsafe_wrap(Array{fmi2ValueReference}, _vr, nvr)

    global FMU_NUM_STATES, FMU_NUM_OUTPUTS, FMU_NUM_INPUTS, FMU_NUM_PARAMETERS

    for i = 1:nvr
        valueRef = vr[i]

        try
            value[i] = component.values[valueRef]
        catch e
            logError(component, "fmi2GetReal: Unknown value reference $(valueRef).")
            return fmi2StatusError
        end
    end

    return fmi2StatusOK
end

function simple_fmi2GetInteger(
    _component::fmi2Component,
    _vr::Ptr{fmi2ValueReference},
    nvr::Csize_t,
    _value::Ptr{fmi2Integer},
)
    component = dereferenceInstance(_component)

    value = unsafe_wrap(Array{fmi2Integer}, _value, nvr)
    vr = unsafe_wrap(Array{fmi2ValueReference}, _vr, nvr)

    global FMU_NUM_STATES, FMU_NUM_OUTPUTS, FMU_NUM_INPUTS, FMU_NUM_PARAMETERS

    for i = 1:nvr
        valueRef = vr[i]

        try
            value[i] = component.values[valueRef]
        catch e
            logError(component, "fmi2GetReal: Unknown value reference $(valueRef).")
            return fmi2StatusError
        end
    end

    return fmi2StatusOK
end

function simple_fmi2GetBoolean(
    _component::fmi2Component,
    _vr::Ptr{fmi2ValueReference},
    nvr::Csize_t,
    _value::Ptr{fmi2Boolean},
)
    component = dereferenceInstance(_component)

    # ToDo
    logWarning(component, "fmi2GetBoolean: Not implemented yet, please open an issue.")

    return fmi2StatusWarning
end

function simple_fmi2GetString(
    _component::fmi2Component,
    _vr::Ptr{fmi2ValueReference},
    nvr::Csize_t,
    _value::Ptr{fmi2String},
)
    component = dereferenceInstance(_component)

    # ToDo
    logWarning(component, "fmi2GetString: Not implemented yet, please open an issue.")

    return fmi2StatusWarning
end

function simple_fmi2SetReal(
    _component::fmi2Component,
    _vr::Ptr{fmi2ValueReference},
    nvr::Csize_t,
    _value::Ptr{fmi2Real},
)
    component = dereferenceInstance(_component)

    value = unsafe_wrap(Array{fmi2Real}, _value, nvr)
    vr = unsafe_wrap(Array{fmi2ValueReference}, _vr, nvr)

    for i = 1:nvr
        valueRef = vr[i]

        try
            component.values[valueRef] = value[i]
        catch e
            logError(component, "fmi2SetReal: Unknown value reference $(valueRef).")
            return fmi2StatusError
        end
    end

    evaluate(_component)

    return fmi2StatusOK
end

function simple_fmi2SetInteger(
    _component::fmi2Component,
    _vr::Ptr{fmi2ValueReference},
    nvr::Csize_t,
    _value::Ptr{fmi2Integer},
)
    component = dereferenceInstance(_component)

    # ToDo
    logWarning(component, "fmi2SetInteger: Not implemented yet, please open an issue.")

    return fmi2StatusWarning
end

function simple_fmi2SetBoolean(
    _component::fmi2Component,
    _vr::Ptr{fmi2ValueReference},
    nvr::Csize_t,
    _value::Ptr{fmi2Boolean},
)
    component = dereferenceInstance(_component)

    # ToDo
    logWarning(component, "fmi2SetBoolean: Not implemented yet, please open an issue.")

    return fmi2StatusWarning
end

function simple_fmi2SetString(
    _component::fmi2Component,
    _vr::Ptr{fmi2ValueReference},
    nvr::Csize_t,
    _value::Ptr{fmi2String},
)
    component = dereferenceInstance(_component)

    # ToDo
    logWarning(component, "fmi2SetString: Not implemented yet, please open an issue.")

    return fmi2StatusWarning
end

function simple_fmi2SetTime(_component::fmi2Component, time::fmi2Real)
    component = dereferenceInstance(_component)

    component.t = time

    evaluate(_component)

    return fmi2StatusOK
end

function simple_fmi2SetContinuousStates(
    _component::fmi2Component,
    _x::Ptr{fmi2Real},
    nx::Csize_t,
)
    component = dereferenceInstance(_component)

    if nx != length(component.fmu.modelDescription.stateValueReferences)
        logWarning(
            component,
            "fmi2SetContinuousStates: Model has $(length(component.fmu.modelDescription.stateValueReferences)) states, but `nx`=$(nx).",
        )
        return fmi2StatusWarning
    end

    x = unsafe_wrap(Array{fmi2Real}, _x, nx)

    for i = 1:nx
        vr = component.fmu.modelDescription.stateValueReferences[i]
        component.values[vr] = x[i]
    end

    evaluate(_component)

    return fmi2StatusOK
end

function simple_fmi2EnterEventMode(_component::fmi2Component)
    component = dereferenceInstance(_component)

    component.state = fmi2ComponentStateEventMode

    return fmi2StatusOK
end

function simple_fmi2NewDiscreteStates(
    _component::fmi2Component,
    _fmi2eventInfo::Ptr{fmi2EventInfo},
)
    component = dereferenceInstance(_component)

    if component.state != fmi2ComponentStateEventMode
        logError(
            component,
            "fmi2NewDiscreteStates must be called in event mode, mode is `$(component.state)`!",
        )
        return fmi2StatusError
    end

    evaluate(_component, true)

    # ToDo: This is not efficient (copy struct and overwrite), direct memory access would be much nicer!
    eventInfo = unsafe_load(_fmi2eventInfo)
    eventInfo.newDiscreteStatesNeeded = fmi2False # component.eventInfo.newDiscreteStatesNeeded
    eventInfo.terminateSimulation = fmi2False # [ToDo]
    eventInfo.nominalsOfContinuousStatesChanged = fmi2False # [ToDo]
    eventInfo.valuesOfContinuousStatesChanged =
        component.eventInfo.valuesOfContinuousStatesChanged
    eventInfo.nextEventTimeDefined = fmi2False # [ToDo]
    eventInfo.nextEventTime = 0.0 # [ToDo] support for time events
    unsafe_store!(_fmi2eventInfo, eventInfo)

    # reset 
    eventInfo.valuesOfContinuousStatesChanged = fmi2False

    return fmi2StatusOK
end

function simple_fmi2EnterContinuousTimeMode(_component::fmi2Component)
    component = dereferenceInstance(_component)

    component.state = fmi2ComponentStateContinuousTimeMode

    return fmi2StatusOK
end

function simple_fmi2CompletedIntegratorStep(
    _component::fmi2Component,
    noSetFMUStatePriorToCurrentPoint::fmi2Boolean,
    _enterEventMode::Ptr{fmi2Boolean},
    _terminateSimulation::Ptr{fmi2Boolean},
)
    component = dereferenceInstance(_component)

    enterEventMode = unsafe_wrap(Array{fmi2Boolean}, _enterEventMode, 1)
    terminateSimulation = unsafe_wrap(Array{fmi2Boolean}, _terminateSimulation, 1)

    enterEventMode[1] = fmi2False
    terminateSimulation[1] = fmi2False

    return fmi2StatusOK
end

function simple_fmi2GetDerivatives(
    _component::fmi2Component,
    _derivatives::Ptr{fmi2Real},
    nx::Csize_t,
)
    component = dereferenceInstance(_component)

    if nx != length(component.fmu.modelDescription.derivativeValueReferences)
        logWarning(
            component,
            "fmi2GetDerivatives: Model has $(length(component.fmu.modelDescription.derivativeValueReferences)) states, but `nx`=$(nx).",
        )
        return fmi2StatusWarning
    end

    derivatives = unsafe_wrap(Array{fmi2Real}, _derivatives, nx)

    for i = 1:nx
        vr = component.fmu.modelDescription.derivativeValueReferences[i]
        derivatives[i] = component.values[vr]
    end

    return fmi2StatusOK
end

function simple_fmi2GetEventIndicators(
    _component::fmi2Component,
    _eventIndicators::Ptr{fmi2Real},
    ni::Csize_t,
)
    component = dereferenceInstance(_component)

    numberOfEventIndicators = component.fmu.modelDescription.numberOfEventIndicators
    if ni != numberOfEventIndicators
        logWarning(
            component,
            "fmi2GetEventIndicators: Model has $(numberOfEventIndicators) event indicators, but `ni`=$(ni).",
        )
        return fmi2StatusWarning
    end

    eventIndicators = unsafe_wrap(Array{fmi2Real}, _eventIndicators, ni)

    t = component.t
    xc, ẋc, xd, u, y, p = extractValues(_component)
    component.z = FMU_FCT_EVENT(t, xc, ẋc, xd, u, p)

    for i = 1:ni
        eventIndicators[i] = component.z[i]
    end

    return fmi2StatusOK
end

function simple_fmi2GetContinuousStates(
    _component::fmi2Component,
    _x::Ptr{fmi2Real},
    nx::Csize_t,
)
    component = dereferenceInstance(_component)

    if nx != length(component.fmu.modelDescription.stateValueReferences)
        logWarning(
            component,
            "fmi2GetContinuousStates: Model has $(length(component.fmu.modelDescription.stateValueReferences)) states, but `nx`=$(nx).",
        )
        return fmi2StatusWarning
    end

    x = unsafe_wrap(Array{fmi2Real}, _x, nx)

    for i = 1:nx
        vr = component.fmu.modelDescription.stateValueReferences[i]
        x[i] = component.values[vr]
    end

    return fmi2StatusOK
end

function simple_fmi2GetNominalsOfContinuousStates(
    _component::fmi2Component,
    _x_nominal::Ptr{fmi2Real},
    nx::Csize_t,
)
    component = dereferenceInstance(_component)

    if nx != length(component.fmu.modelDescription.stateValueReferences)
        logWarning(
            component,
            "fmi2GetNominalsOfContinuousStates: Model has $(length(component.fmu.modelDescription.stateValueReferences)) states, but `nx`=$(nx).",
        )
        return fmi2StatusWarning
    end

    x_nominal = unsafe_wrap(Array{fmi2Real}, _x_nominal, nx)

    for i = 1:nx
        #vr = component.fmu.modelDescription.stateValueReferences[i]
        x_nominal[i] = 1.0
    end

    return fmi2StatusOK
end

""" 
    initializationFct           # () -> (t, xc, ẋc, xd, u, p)
    evaluationFct               # (t, xc, ẋc, xd, u, p, event) -> (xc, ẋc, xd, p)
    outputFct                   # (t, xc, ẋc, xd, u, p) -> y
    eventFct                    # (t, xc, ẋc, xd, u, p) -> e
"""
function createFMU2Simple(
    modelName::String="";
    initializationFct=nothing,
    evaluationFct=nothing,
    outputFct=nothing,
    eventFct=nothing,
    type=fmi2TypeModelExchange,
)

    global FMIBUILD_FMU

    global FMU_FCT_INIT
    global FMU_FCT_EVALUATE
    global FMU_FCT_OUTPUT
    global FMU_FCT_EVENT

    global FMU_NUM_STATES
    global FMU_NUM_DISCRETE_STATES
    global FMU_NUM_OUTPUTS
    global FMU_NUM_INPUTS
    global FMU_NUM_EVENTS
    global FMU_NUM_PARAMETERS

    FMIBUILD_FMU = createFMU2(modelName; type=type)

    if type == fmi2TypeCoSimulation
        _enable_cs_export(FMIBUILD_FMU)
    end

    FMU_FCT_INIT = initializationFct
    FMU_FCT_EVALUATE = evaluationFct
    FMU_FCT_OUTPUT = outputFct
    FMU_FCT_EVENT = eventFct

    t, xc, ẋc, xd, u, p = FMU_FCT_INIT()
    y = FMU_FCT_OUTPUT(t, xc, ẋc, xd, u, p)
    e = FMU_FCT_EVENT(t, xc, ẋc, xd, u, p)

    FMU_NUM_STATES = length(xc)
    FMU_NUM_DISCRETE_STATES = length(xd)
    FMU_NUM_OUTPUTS = length(y)
    FMU_NUM_INPUTS = length(u)
    FMU_NUM_EVENTS = length(e)
    FMU_NUM_PARAMETERS = length(p)

    # ToDo: only register subset of function pointers depending on the FMU type (ME or CS).
    setFctGetVersion(FMIBUILD_FMU, simple_fmi2GetVersion)
    setFctGetTypesPlatform(FMIBUILD_FMU, simple_fmi2GetTypesPlatform)
    setFctInstantiate(FMIBUILD_FMU, simple_fmi2Instantiate)
    setFctFreeInstance(FMIBUILD_FMU, simple_fmi2FreeInstance)
    setFctSetDebugLogging(FMIBUILD_FMU, simple_fmi2SetDebugLogging)
    setFctSetupExperiment(FMIBUILD_FMU, simple_fmi2SetupExperiment)
    setFctEnterInitializationMode(FMIBUILD_FMU, simple_fmi2EnterInitializationMode)
    setFctExitInitializationMode(FMIBUILD_FMU, simple_fmi2ExitInitializationMode)
    setFctTerminate(FMIBUILD_FMU, simple_fmi2Terminate)
    setFctReset(FMIBUILD_FMU, simple_fmi2Reset)
    setFctGetReal(FMIBUILD_FMU, simple_fmi2GetReal)
    setFctGetInteger(FMIBUILD_FMU, simple_fmi2GetInteger)
    setFctGetBoolean(FMIBUILD_FMU, simple_fmi2GetBoolean)
    setFctGetString(FMIBUILD_FMU, simple_fmi2GetString)
    setFctSetReal(FMIBUILD_FMU, simple_fmi2SetReal)
    setFctSetInteger(FMIBUILD_FMU, simple_fmi2SetInteger)
    setFctSetBoolean(FMIBUILD_FMU, simple_fmi2SetBoolean)
    setFctSetString(FMIBUILD_FMU, simple_fmi2SetString)
    setFctSetTime(FMIBUILD_FMU, simple_fmi2SetTime)
    setFctSetContinuousStates(FMIBUILD_FMU, simple_fmi2SetContinuousStates)
    setFctEnterEventMode(FMIBUILD_FMU, simple_fmi2EnterEventMode)
    setFctNewDiscreteStates(FMIBUILD_FMU, simple_fmi2NewDiscreteStates)
    setFctEnterContinuousTimeMode(FMIBUILD_FMU, simple_fmi2EnterContinuousTimeMode)
    setFctCompletedIntegratorStep(FMIBUILD_FMU, simple_fmi2CompletedIntegratorStep)
    setFctGetDerivatives(FMIBUILD_FMU, simple_fmi2GetDerivatives)
    setFctGetEventIndicators(FMIBUILD_FMU, simple_fmi2GetEventIndicators)
    setFctGetContinuousStates(FMIBUILD_FMU, simple_fmi2GetContinuousStates)
    setFctGetNominalsOfContinuousStates(
        FMIBUILD_FMU,
        simple_fmi2GetNominalsOfContinuousStates,
    )

    setFctSetRealInputDerivatives(FMIBUILD_FMU, simple_fmi2SetRealInputDerivatives)
    setFctGetRealOutputDerivatives(FMIBUILD_FMU, simple_fmi2GetRealOutputDerivatives)
    setFctDoStep(FMIBUILD_FMU, simple_fmi2DoStep)
    setFctCancelStep(FMIBUILD_FMU, simple_fmi2CancelStep)
    setFctGetStatus(FMIBUILD_FMU, simple_fmi2GetStatus)
    setFctGetRealStatus(FMIBUILD_FMU, simple_fmi2GetRealStatus)
    setFctGetIntegerStatus(FMIBUILD_FMU, simple_fmi2GetIntegerStatus)
    setFctGetBooleanStatus(FMIBUILD_FMU, simple_fmi2GetBooleanStatus)
    setFctGetStringStatus(FMIBUILD_FMU, simple_fmi2GetStringStatus)

    return FMIBUILD_FMU
end
export createFMU2Simple
