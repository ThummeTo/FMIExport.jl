#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

FMU_NUM_STATES = 0
# FMU_NUM_DERIVATIVES = FMU_NUM_STATES
FMU_NUM_OUTPUTS = 0
FMU_NUM_INPUTS = 0
FMU_NUM_EVENTS = 0
FMU_NUM_PARAMETERS = 0

FMU_FCT_INIT = function() return ([],[],[],[],[]) end
FMU_FCT_EVALUATE = function(t, x, ẋ, u, p) return ([], [], []) end
FMU_FCT_OUTPUT = function(t, x, ẋ, u, p) return [] end
FMU_FCT_EVENT = function(t, x, ẋ, u, p) return [] end

##############

function logInfo(_component::fmi2Component, status::fmi2Status, message)
    component = dereferenceComponent(_component)
    if component != nothing
        if component.loggingOn == fmi2True
            ccall(component.callbackFunctions.logger, Cvoid, (fmi2ComponentEnvironment, fmi2String, fmi2Status, fmi2String, fmi2String), component.callbackFunctions.componentEnvironment, component.instanceName, status, "info", message * "\n")
        end
    end
end

function logWarning(_component::fmi2Component, status::fmi2Status, message)
    component = dereferenceComponent(_component)
    if component != nothing
        ccall(component.callbackFunctions.logger, Cvoid, (fmi2ComponentEnvironment, fmi2String, fmi2Status, fmi2String, fmi2String), component.callbackFunctions.componentEnvironment, component.instanceName, status, "warning", message * "\n")
    end
end

function logError(_component::fmi2Component, status::fmi2Status, message)
    component = dereferenceComponent(_component)
    if component != nothing
        ccall(component.callbackFunctions.logger, Cvoid, (fmi2ComponentEnvironment, fmi2String, fmi2Status, fmi2String, fmi2String), component.callbackFunctions.componentEnvironment, component.instanceName, status, "error", message * "\n")
    end
end

function dereferenceComponent(addr::fmi2Component)
    global FMIBUILD_FMU
    for component in FMIBUILD_FMU.components
        if addr == component.compAddr
            return component
        end
    end

    @warn "Unknown fmi2Component at $(addr)."
    return nothing
end

function reset(_component::fmi2Component)
    component = dereferenceComponent(_component)

    (component.t, x, ẋ, u, p) = FMU_FCT_INIT()
    component.z = FMU_FCT_EVENT(component.t, x, ẋ, u, p)
    y = FMU_FCT_OUTPUT(component.t, x, ẋ, u, p)

    applyValues(component.compAddr, x, ẋ, u, y, p)
end

function evaluate(_component::fmi2Component)
    component = dereferenceComponent(_component)

    x, ẋ, u, y, p = extractValues(_component)

    x, ẋ, p = FMU_FCT_EVALUATE(component.t, x, ẋ, u, p)
    y       = FMU_FCT_OUTPUT(  component.t, x, ẋ, u, p)
    z_new   = FMU_FCT_EVENT(   component.t, x, ẋ, u, p)

    applyValues(_component, x, ẋ, u, y, p)

    # event triggering

    if (component.z_prev != nothing) && (sign.(z_new) != sign.(component.z_prev))
        component.continuousStatesChanged = fmi2True 
        component.z_prev = z_new
        component.z      = z_new
    else 
        component.z_prev = component.z
        component.z      = z_new
    end
end

function applyValues(_component::fmi2Component, x, ẋ, u, y, p)
    component = dereferenceComponent(_component)

    for i in 1:length(FMIBUILD_FMU.modelDescription.stateValueReferences)
        vr = FMIBUILD_FMU.modelDescription.stateValueReferences[i]
        component.realValues[vr] = x[i]
    end

    for i in 1:length(FMIBUILD_FMU.modelDescription.derivativeValueReferences)
        vr = FMIBUILD_FMU.modelDescription.derivativeValueReferences[i]
        component.realValues[vr] = ẋ[i]
    end

    for i in 1:length(FMIBUILD_FMU.modelDescription.inputValueReferences)
        vr = FMIBUILD_FMU.modelDescription.inputValueReferences[i]
        component.realValues[vr] = u[i]
    end

    for i in 1:length(FMIBUILD_FMU.modelDescription.outputValueReferences)
        vr = FMIBUILD_FMU.modelDescription.outputValueReferences[i]
        component.realValues[vr] = y[i]
    end

    for i in 1:length(FMIBUILD_FMU.modelDescription.parameterValueReferences)
        vr = FMIBUILD_FMU.modelDescription.parameterValueReferences[i]
        component.realValues[vr] = p[i]
    end

    nothing
end

function extractValues(_component::fmi2Component)
    component = dereferenceComponent(_component)

    xs = collect(component.realValues[vr] for vr in component.fmu.modelDescription.stateValueReferences)
    ẋs = collect(component.realValues[vr] for vr in component.fmu.modelDescription.derivativeValueReferences)
    us = collect(component.realValues[vr] for vr in component.fmu.modelDescription.inputValueReferences)
    ys = collect(component.realValues[vr] for vr in component.fmu.modelDescription.outputValueReferences)
    ps = collect(component.realValues[vr] for vr in component.fmu.modelDescription.parameterValueReferences)

    return xs, ẋs, us, ys, ps 
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
function simple_fmi2Instantiate(instanceName::fmi2String,
                                         fmuType::fmi2Type,
                                         fmuGUID::fmi2String,
                                         fmuResourceLocation::fmi2String,
                                         functions::Ptr{fmi2CallbackFunctions},
                                         visible::fmi2Boolean,
                                         loggingOn::fmi2Boolean)
                                        
    global FMIBUILD_FMU
                                 
    component = FMU2Component()
    component.loggingOn = loggingOn
    component.callbackFunctions = unsafe_load(functions)
    component.instanceName = unsafe_string(instanceName)

    component.compAddr = pointer_from_objref(component)
    component.fmu = FMIBUILD_FMU
    push!(FMIBUILD_FMU.components, component)

    reset(component.compAddr)

    logInfo(component.compAddr, fmi2StatusOK, "fmi2Instantiate: New fmi2Component at $(component.compAddr)")

    return component.compAddr
end

function simple_fmi2FreeInstance(_component::fmi2Component)
    component = dereferenceComponent(_component)

    if component != nothing
        logInfo(component.compAddr, fmi2StatusOK, "fmi2FreeInstance")
    
        global FMIBUILD_FMU
        for i in 1:length(FMIBUILD_FMU.components)
            if FMIBUILD_FMU.components[i].compAddr == component.compAddr
                deleteat!(FMIBUILD_FMU.components, i)
                break
            end
        end
        logInfo(component.compAddr, fmi2StatusOK, "fmi2FreeInstance: Freed fmi2Component at $(component.compAddr).")
    end

    nothing
end

function simple_fmi2SetDebugLogging(_component::fmi2Component, loggingOn::fmi2Boolean, nCategories::Csize_t, categories::Ptr{fmi2String}) 
    component = dereferenceComponent(_component)
    logInfo(component.compAddr, fmi2StatusOK, "fmi2SetDebugLogging")

    component.loggingOn = loggingOn
    # ToDo: categories (arguments)

    return fmi2StatusOK
end

function simple_fmi2SetupExperiment(_component::fmi2Component, toleranceDefined::fmi2Boolean, tolerance::fmi2Real, startTime::fmi2Real, stopTimeDefined::fmi2Boolean, stopTime::fmi2Real) 
    component = dereferenceComponent(_component)
    logInfo(component.compAddr, fmi2StatusOK, "fmi2SetupExperiment")

    # ToDo

    return fmi2StatusOK
end

function simple_fmi2EnterInitializationMode(_component::fmi2Component) 
    component = dereferenceComponent(_component)
    logInfo(component.compAddr, fmi2StatusOK, "fmi2EnterInitializationMode")

    # ToDo

    return fmi2StatusOK
end

function simple_fmi2ExitInitializationMode(_component::fmi2Component) 
    component = dereferenceComponent(_component)
    logInfo(component.compAddr, fmi2StatusOK, "fmi2ExitInitializationMode")

    # ToDo

    return fmi2StatusOK
end

function simple_fmi2Terminate(_component::fmi2Component)
    component = dereferenceComponent(_component)
    logInfo(component.compAddr, fmi2StatusOK, "fmi2Terminate")

    # ToDo

    return fmi2StatusOK
end

function simple_fmi2Reset(_component::fmi2Component)
    component = dereferenceComponent(_component)
    logInfo(component.compAddr, fmi2StatusOK, "fmi2Reset")

    reset(_component)

    return fmi2StatusOK
end

function simple_fmi2GetReal(_component::fmi2Component, _vr::Ptr{fmi2ValueReference}, nvr::Csize_t, _value::Ptr{fmi2Real}) 
    component = dereferenceComponent(_component)
    logInfo(component.compAddr, fmi2StatusOK, "fmi2GetReal")

    value = unsafe_wrap(Array{fmi2Real}, _value, nvr)
    vr = unsafe_wrap(Array{fmi2ValueReference}, _vr, nvr)

    global FMU_NUM_STATES, FMU_NUM_OUTPUTS, FMU_NUM_INPUTS, FMU_NUM_PARAMETERS

    for i in 1:nvr
        valueRef = vr[i]

        try
            value[i] = component.realValues[valueRef]
        catch e
            logError(component.compAddr, fmi2StatusError, "fmi2SetReal: Unknown value reference $(valueRef).\n")
            return fmi2StatusError
        end
    end

    return fmi2StatusOK
end

function simple_fmi2GetInteger(_component::fmi2Component, _vr::Ptr{fmi2ValueReference}, nvr::Csize_t, _value::Ptr{fmi2Integer})
    component = dereferenceComponent(_component)
    logInfo(component.compAddr, fmi2StatusOK, "fmi2GetInteger")

    # ToDo

    return fmi2StatusOK
end

function simple_fmi2GetBoolean(_component::fmi2Component, _vr::Ptr{fmi2ValueReference}, nvr::Csize_t, _value::Ptr{fmi2Boolean})
    component = dereferenceComponent(_component)
    logInfo(component.compAddr, fmi2StatusOK, "fmi2GetBoolean")

    # ToDo

    return fmi2StatusOK
end

function simple_fmi2GetString(_component::fmi2Component, _vr::Ptr{fmi2ValueReference}, nvr::Csize_t, _value::Ptr{fmi2String})
    component = dereferenceComponent(_component)
    logInfo(component.compAddr, fmi2StatusOK, "fmi2GetString")

    # ToDo

    return fmi2StatusOK
end

function simple_fmi2SetReal(_component::fmi2Component, _vr::Ptr{fmi2ValueReference}, nvr::Csize_t, _value::Ptr{fmi2Real})
    component = dereferenceComponent(_component)
    logInfo(component.compAddr, fmi2StatusOK, "fmi2SetReal")

    value = unsafe_wrap(Array{fmi2Real}, _value, nvr)
    vr = unsafe_wrap(Array{fmi2ValueReference}, _vr, nvr)

    for i in 1:nvr
        valueRef = vr[i]

        try
            component.realValues[valueRef] = value[i]
        catch e
            logError(component.compAddr, fmi2StatusError, "fmi2SetReal: Unknown value reference $(valueRef).\n")
            return fmi2StatusError
        end
    end

    evaluate(_component)

    return fmi2StatusOK
end

function simple_fmi2SetInteger(_component::fmi2Component, _vr::Ptr{fmi2ValueReference}, nvr::Csize_t, _value::Ptr{fmi2Integer})
    component = dereferenceComponent(_component)
    logInfo(component.compAddr, fmi2StatusOK, "fmi2SetInteger")

    # ToDo

    return fmi2StatusOK
end

function simple_fmi2SetBoolean(_component::fmi2Component, _vr::Ptr{fmi2ValueReference}, nvr::Csize_t, _value::Ptr{fmi2Boolean})
    component = dereferenceComponent(_component)
    logInfo(component.compAddr, fmi2StatusOK, "fmi2SetBoolean")

    # ToDo

    return fmi2StatusOK
end

function simple_fmi2SetString(_component::fmi2Component, _vr::Ptr{fmi2ValueReference}, nvr::Csize_t, _value::Ptr{fmi2String})
    component = dereferenceComponent(_component)
    logInfo(component.compAddr, fmi2StatusOK, "fmi2SetString")

    # ToDo

    return fmi2StatusOK
end

function simple_fmi2SetTime(_component::fmi2Component, time::fmi2Real)
    component = dereferenceComponent(_component)
    logInfo(component.compAddr, fmi2StatusOK, "fmi2SetTime")

    component.t = time

    evaluate(_component)

    return fmi2StatusOK
end

function simple_fmi2SetContinuousStates(_component::fmi2Component, _x::Ptr{fmi2Real}, nx::Csize_t) 
    component = dereferenceComponent(_component)
    logInfo(component.compAddr, fmi2StatusOK, "fmi2SetContinuousStates")

    if nx != length(component.fmu.modelDescription.stateValueReferences)
        logWarning(component.compAddr, fmi2StatusWarning, "fmi2SetContinuousStates: Model has $(length(component.fmu.modelDescription.stateValueReferences)) states, but `nx`=$(nx).")
    end

    x = unsafe_wrap(Array{fmi2Real}, _x, nx)
    
    for i in 1:nx
        vr = component.fmu.modelDescription.stateValueReferences[i]
        component.realValues[vr] = x[i]
    end

    evaluate(_component)

    return fmi2StatusOK
end

function simple_fmi2EnterEventMode(_component::fmi2Component)
    component = dereferenceComponent(_component)
    logInfo(component.compAddr, fmi2StatusOK, "fmi2EnterEventMode")

    # ToDo

    return fmi2StatusOK
end

function simple_fmi2NewDiscreteStates(_component::fmi2Component, _fmi2eventInfo::Ptr{fmi2EventInfo})
    component = dereferenceComponent(_component)
    logInfo(component.compAddr, fmi2StatusOK, "fmi2NewDiscreteStates")

    # ToDo: This is not efficient (copy struct and overwrite), direct memory access would be much nicer!
    eventInfo = unsafe_load(_fmi2eventInfo)
    eventInfo.newDiscreteStatesNeeded = fmi2False
    eventInfo.terminateSimulation = fmi2False
    eventInfo.nominalsOfContinuousStatesChanged = fmi2False
    eventInfo.valuesOfContinuousStatesChanged = component.continuousStatesChanged
    eventInfo.nextEventTimeDefined = fmi2False
    eventInfo.nextEventTime = 0.0
    unsafe_store!(_fmi2eventInfo, eventInfo);

    component.continuousStatesChanged = fmi2False
    
    return fmi2StatusOK
end

function simple_fmi2EnterContinuousTimeMode(_component::fmi2Component)
    component = dereferenceComponent(_component)
    logInfo(component.compAddr, fmi2StatusOK, "fmi2EnterContinuousTimeMode")

    # ToDo

    return fmi2StatusOK
end

function simple_fmi2CompletedIntegratorStep(_component::fmi2Component, noSetFMUStatePriorToCurrentPoint::fmi2Boolean, enterEventMode::Ptr{fmi2Boolean}, terminateSimulation::Ptr{fmi2Boolean}) 
    component = dereferenceComponent(_component)
    logInfo(component.compAddr, fmi2StatusOK, "fmi2CompletedIntegratorStep")

    # ToDo

    return fmi2StatusOK
end

function simple_fmi2GetDerivatives(_component::fmi2Component, _derivatives::Ptr{fmi2Real}, nx::Csize_t)
    component = dereferenceComponent(_component)
    logInfo(component.compAddr, fmi2StatusOK, "fmi2GetDerivatives")

    if nx != length(component.fmu.modelDescription.derivativeValueReferences)
        logWarning(component.compAddr, fmi2StatusWarning, "fmi2GetDerivatives: Model has $(length(component.fmu.modelDescription.derivativeValueReferences)) states, but `nx`=$(nx).")
    end

    derivatives = unsafe_wrap(Array{fmi2Real}, _derivatives, nx)
    
    for i in 1:nx
        vr = component.fmu.modelDescription.derivativeValueReferences[i]
        derivatives[i] = component.realValues[vr]
    end

    return fmi2StatusOK
end

function simple_fmi2GetEventIndicators(_component::fmi2Component, _eventIndicators::Ptr{fmi2Real}, ni::Csize_t)
    component = dereferenceComponent(_component)
    logInfo(component.compAddr, fmi2StatusOK, "fmi2GetEventIndicators")

    if ni != length(component.fmu.modelDescription.numberOfEventIndicators)
        logWarning(component.compAddr, fmi2StatusWarning, "fmi2GetEventIndicators: Model has $(length(component.eventIndicators)) states, but `ni`=$(ni).")
    end

    eventIndicators = unsafe_wrap(Array{fmi2Real}, _eventIndicators, ni)
    
    for i in 1:ni
        eventIndicators[i] = component.z[i]
    end

    return fmi2StatusOK
end

function simple_fmi2GetContinuousStates(_component::fmi2Component, _x::Ptr{fmi2Real}, nx::Csize_t)
    component = dereferenceComponent(_component)
    logInfo(component.compAddr, fmi2StatusOK, "fmi2GetContinuousStates")

    if nx != length(component.fmu.modelDescription.stateValueReferences)
        logWarning(component.compAddr, fmi2StatusWarning, "fmi2GetContinuousStates: Model has $(length(component.fmu.modelDescription.stateValueReferences)) states, but `nx`=$(nx).")
    end

    x = unsafe_wrap(Array{fmi2Real}, _x, nx)
    
    for i in 1:nx
        vr = component.fmu.modelDescription.stateValueReferences[i]
        x[i] = component.realValues[vr]
    end

    return fmi2StatusOK
end

function simple_fmi2GetNominalsOfContinuousStates(_component::fmi2Component, _x_nominal::Ptr{fmi2Real}, nx::Csize_t) 
    component = dereferenceComponent(_component)
    logInfo(component.compAddr, fmi2StatusOK, "fmi2GetNominalsOfContinuousStates")

    if nx != length(component.fmu.modelDescription.stateValueReferences)
        logWarning(component.compAddr, fmi2StatusWarning, "fmi2GetNominalsOfContinuousStates: Model has $(length(component.fmu.modelDescription.stateValueReferences)) states, but `nx`=$(nx).")
    end

    x_nominal = unsafe_wrap(Array{fmi2Real}, _x_nominal, nx)
    
    for i in 1:nx
        vr = component.fmu.modelDescription.stateValueReferences[i]
        x_nominal[i] = component.realValues[vr]
    end

    return fmi2StatusOK
end

""" 
    initializationFct           # () -> (t, x, ẋ, u, p)
    evaluationFct               # (t, x, ẋ, u, p) -> (x, ẋ, p)
    outputFct                   # (t, x, ẋ, u, p) -> y
    eventFct                    # (t, x, ẋ, u, p) -> e
"""
function fmi2CreateSimple(;
    initializationFct=nothing,
    evaluationFct=nothing,
    outputFct=nothing,
    eventFct=nothing)

    global FMIBUILD_FMU

    global FMU_FCT_INIT
    global FMU_FCT_EVALUATE 
    global FMU_FCT_OUTPUT
    global FMU_FCT_EVENT 

    global FMU_NUM_STATES
    global FMU_NUM_OUTPUTS
    global FMU_NUM_INPUTS
    global FMU_NUM_EVENTS 
    global FMU_NUM_PARAMETERS 

    FMIBUILD_FMU = fmi2Create()

    FMU_FCT_INIT = initializationFct
    FMU_FCT_EVALUATE = evaluationFct
    FMU_FCT_OUTPUT = outputFct
    FMU_FCT_EVENT = eventFct

    t, x, ẋ, u, p = FMU_FCT_INIT()
    y = FMU_FCT_OUTPUT(t, x, ẋ, u, p)
    e = FMU_FCT_EVENT(t, x, ẋ, u, p)

    FMU_NUM_STATES = length(x)
    FMU_NUM_OUTPUTS = length(y)
    FMU_NUM_INPUTS = length(u)
    FMU_NUM_EVENTS = length(e)
    FMU_NUM_PARAMETERS  = length(p)
    
    fmi2SetFctGetVersion(FMIBUILD_FMU,                     simple_fmi2GetVersion)
    fmi2SetFctGetTypesPlatform(FMIBUILD_FMU,               simple_fmi2GetTypesPlatform)
    fmi2SetFctInstantiate(FMIBUILD_FMU,                    simple_fmi2Instantiate)
    #FMIBUILD_FMU.cInstantiate = @cfunction(simple_fmi2Instantiate, fmi2Component, (fmi2String, fmi2Type, fmi2String, fmi2String, Ptr{fmi2CallbackFunctions}, fmi2Boolean, fmi2Boolean))
    fmi2SetFctFreeInstance(FMIBUILD_FMU,                   simple_fmi2FreeInstance)
    fmi2SetFctSetDebugLogging(FMIBUILD_FMU,                simple_fmi2SetDebugLogging)
    fmi2SetFctSetupExperiment(FMIBUILD_FMU,                simple_fmi2SetupExperiment)
    fmi2SetEnterInitializationMode(FMIBUILD_FMU,           simple_fmi2EnterInitializationMode)
    fmi2SetFctExitInitializationMode(FMIBUILD_FMU,         simple_fmi2ExitInitializationMode)
    fmi2SetFctTerminate(FMIBUILD_FMU,                      simple_fmi2Terminate)
    fmi2SetFctReset(FMIBUILD_FMU,                          simple_fmi2Reset)
    fmi2SetFctGetReal(FMIBUILD_FMU,                        simple_fmi2GetReal)
    fmi2SetFctGetInteger(FMIBUILD_FMU,                     simple_fmi2GetInteger)
    fmi2SetFctGetBoolean(FMIBUILD_FMU,                     simple_fmi2GetBoolean)
    fmi2SetFctGetString(FMIBUILD_FMU,                      simple_fmi2GetString)
    fmi2SetFctSetReal(FMIBUILD_FMU,                        simple_fmi2SetReal)
    fmi2SetFctSetInteger(FMIBUILD_FMU,                     simple_fmi2SetInteger)
    fmi2SetFctSetBoolean(FMIBUILD_FMU,                     simple_fmi2SetBoolean)
    fmi2SetFctSetString(FMIBUILD_FMU,                      simple_fmi2SetString)
    fmi2SetFctSetTime(FMIBUILD_FMU,                        simple_fmi2SetTime)
    fmi2SetFctSetContinuousStates(FMIBUILD_FMU,            simple_fmi2SetContinuousStates)
    fmi2SetFctEnterEventMode(FMIBUILD_FMU,                 simple_fmi2EnterEventMode)
    fmi2SetFctNewDiscreteStates(FMIBUILD_FMU,              simple_fmi2NewDiscreteStates)
    fmi2SetFctEnterContinuousTimeMode(FMIBUILD_FMU,        simple_fmi2EnterContinuousTimeMode)
    fmi2SetFctCompletedIntegratorStep(FMIBUILD_FMU,        simple_fmi2CompletedIntegratorStep)
    fmi2SetFctGetDerivatives(FMIBUILD_FMU,                 simple_fmi2GetDerivatives)
    fmi2SetFctGetEventIndicators(FMIBUILD_FMU,             simple_fmi2GetEventIndicators)
    fmi2SetFctGetContinuousStates(FMIBUILD_FMU,            simple_fmi2GetContinuousStates)
    fmi2SetFctGetNominalsOfContinuousStates(FMIBUILD_FMU,  simple_fmi2GetNominalsOfContinuousStates)
    
    return FMIBUILD_FMU
end