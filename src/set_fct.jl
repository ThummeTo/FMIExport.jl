#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

function setFctGetTypesPlatform(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2String, ())
    fmu.cGetTypesPlatform = c_fun.ptr
end
export setFctGetTypesPlatform

function setFctGetVersion(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2String, ())
    fmu.cGetVersion = c_fun.ptr
end
export setFctGetVersion

function setFctInstantiate(fmu::FMU2, fun)
    c_fun = @cfunction(
        $fun,
        fmi2Component,
        (
            fmi2String,
            fmi2Type,
            fmi2String,
            fmi2String,
            Ptr{fmi2CallbackFunctions},
            fmi2Boolean,
            fmi2Boolean,
        )
    )
    fmu.cInstantiate = c_fun.ptr
end
export setFctInstantiate

function setFctFreeInstance(fmu::FMU2, fun)
    c_fun = @cfunction($fun, Cvoid, (fmi2Component,))
    fmu.cFreeInstance = c_fun.ptr
end
export setFctFreeInstance

function setFctSetDebugLogging(fmu::FMU2, fun)
    c_fun =
        @cfunction($fun, fmi2Status, (fmi2Component, fmi2Boolean, Csize_t, Ptr{fmi2String}))
    fmu.cSetDebugLogging = c_fun.ptr
end
export setFctSetDebugLogging

function setFctSetupExperiment(fmu::FMU2, fun)
    c_fun = @cfunction(
        $fun,
        fmi2Status,
        (fmi2Component, fmi2Boolean, fmi2Real, fmi2Real, fmi2Boolean, fmi2Real)
    )
    fmu.cSetupExperiment = c_fun.ptr
end
export setFctSetupExperiment

function setFctEnterInitializationMode(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component,))
    fmu.cEnterInitializationMode = c_fun.ptr
end
export setFctEnterInitializationMode

function setFctExitInitializationMode(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component,))
    fmu.cExitInitializationMode = c_fun.ptr
end
export setFctExitInitializationMode

function setFctTerminate(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component,))
    fmu.cTerminate = c_fun.ptr
end
export setFctTerminate

function setFctReset(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component,))
    fmu.cReset = c_fun.ptr
end
export setFctReset

function setFctGetReal(fmu::FMU2, fun)
    c_fun = @cfunction(
        $fun,
        fmi2Status,
        (fmi2Component, Ptr{fmi2ValueReference}, Csize_t, Ptr{fmi2Real})
    )
    fmu.cGetReal = c_fun.ptr
end
export setFctGetReal

function setFctGetInteger(fmu::FMU2, fun)
    c_fun = @cfunction(
        $fun,
        fmi2Status,
        (fmi2Component, Ptr{fmi2ValueReference}, Csize_t, Ptr{fmi2Integer})
    )
    fmu.cGetInteger = c_fun.ptr
end
export setFctGetInteger

function setFctGetBoolean(fmu::FMU2, fun)
    c_fun = @cfunction(
        $fun,
        fmi2Status,
        (fmi2Component, Ptr{fmi2ValueReference}, Csize_t, Ptr{fmi2Boolean})
    )
    fmu.cGetBoolean = c_fun.ptr
end
export setFctGetBoolean

function setFctGetString(fmu::FMU2, fun)
    c_fun = @cfunction(
        $fun,
        fmi2Status,
        (fmi2Component, Ptr{fmi2ValueReference}, Csize_t, Ptr{fmi2String})
    )
    fmu.cGetString = c_fun.ptr
end
export setFctGetString

function setFctSetReal(fmu::FMU2, fun)
    c_fun = @cfunction(
        $fun,
        fmi2Status,
        (fmi2Component, Ptr{fmi2ValueReference}, Csize_t, Ptr{fmi2Real})
    )
    fmu.cSetReal = c_fun.ptr
end
export setFctSetReal

function setFctSetInteger(fmu::FMU2, fun)
    c_fun = @cfunction(
        $fun,
        fmi2Status,
        (fmi2Component, Ptr{fmi2ValueReference}, Csize_t, Ptr{fmi2Integer})
    )
    fmu.cSetInteger = c_fun.ptr
end
export setFctSetInteger

function setFctSetBoolean(fmu::FMU2, fun)
    c_fun = @cfunction(
        $fun,
        fmi2Status,
        (fmi2Component, Ptr{fmi2ValueReference}, Csize_t, Ptr{fmi2Boolean})
    )
    fmu.cSetBoolean = c_fun.ptr
end
export setFctSetBoolean

function setFctSetString(fmu::FMU2, fun)
    c_fun = @cfunction(
        $fun,
        fmi2Status,
        (fmi2Component, Ptr{fmi2ValueReference}, Csize_t, Ptr{fmi2String})
    )
    fmu.cSetString = c_fun.ptr
end
export setFctSetString

function setFctSetTime(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component, fmi2Real))
    fmu.cSetTime = c_fun.ptr
end
export setFctSetTime

function setFctSetContinuousStates(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component, Ptr{fmi2Real}, Csize_t))
    fmu.cSetContinuousStates = c_fun.ptr
end
export setFctSetContinuousStates

function setFctEnterEventMode(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component,))
    fmu.cEnterEventMode = c_fun.ptr
end
export setFctEnterEventMode

function setFctNewDiscreteStates(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component, Ptr{fmi2EventInfo}))
    fmu.cNewDiscreteStates = c_fun.ptr
end
export setFctNewDiscreteStates

function setFctEnterContinuousTimeMode(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component,))
    fmu.cEnterContinuousTimeMode = c_fun.ptr
end
export setFctEnterContinuousTimeMode

function setFctCompletedIntegratorStep(fmu::FMU2, fun)
    c_fun = @cfunction(
        $fun,
        fmi2Status,
        (fmi2Component, fmi2Boolean, Ptr{fmi2Boolean}, Ptr{fmi2Boolean})
    )
    fmu.cCompletedIntegratorStep = c_fun.ptr
end
export setFctCompletedIntegratorStep

function setFctGetDerivatives(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component, Ptr{fmi2Real}, Csize_t))
    fmu.cGetDerivatives = c_fun.ptr
end
export setFctGetDerivatives

function setFctGetEventIndicators(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component, Ptr{fmi2Real}, Csize_t))
    fmu.cGetEventIndicators = c_fun.ptr
end
export setFctGetEventIndicators

function setFctGetContinuousStates(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component, Ptr{fmi2Real}, Csize_t))
    fmu.cGetContinuousStates = c_fun.ptr
end
export setFctGetContinuousStates

function setFctGetNominalsOfContinuousStates(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component, Ptr{fmi2Real}, Csize_t))
    fmu.cGetNominalsOfContinuousStates = c_fun.ptr
end
export setFctGetNominalsOfContinuousStates

function setFctSetRealInputDerivatives(fmu::FMU2, fun)
    c_fun = @cfunction(
        $fun,
        fmi2Status,
        (fmi2Component, Ptr{fmi2ValueReference}, Csize_t, Ptr{fmi2Integer}, Ptr{fmi2Real})
    )
    fmu.cSetRealInputDerivatives = c_fun.ptr
end
export setFctSetRealInputDerivatives

function setFctGetRealOutputDerivatives(fmu::FMU2, fun)
    c_fun = @cfunction(
        $fun,
        fmi2Status,
        (fmi2Component, Ptr{fmi2ValueReference}, Csize_t, Ptr{fmi2Integer}, Ptr{fmi2Real})
    )
    fmu.cGetRealOutputDerivatives = c_fun.ptr
end
export setFctGetRealOutputDerivatives

function setFctDoStep(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component, fmi2Real, fmi2Real, fmi2Boolean))
    fmu.cDoStep = c_fun.ptr
end
export setFctDoStep

function setFctCancelStep(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component,))
    fmu.cCancelStep = c_fun.ptr
end
export setFctCancelStep

function setFctGetStatus(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component, fmi2StatusKind, Ptr{fmi2Status}))
    fmu.cGetStatus = c_fun.ptr
end
export setFctGetStatus

function setFctGetRealStatus(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component, fmi2StatusKind, Ptr{fmi2Real}))
    fmu.cGetRealStatus = c_fun.ptr
end
export setFctGetRealStatus

function setFctGetIntegerStatus(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component, fmi2StatusKind, Ptr{fmi2Integer}))
    fmu.cGetIntegerStatus = c_fun.ptr
end
export setFctGetIntegerStatus

function setFctGetBooleanStatus(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component, fmi2StatusKind, Ptr{fmi2Boolean}))
    fmu.cGetBooleanStatus = c_fun.ptr
end
export setFctGetBooleanStatus

function setFctGetStringStatus(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component, fmi2StatusKind, Ptr{fmi2String}))
    fmu.cGetStringStatus = c_fun.ptr
end
export setFctGetStringStatus

const _SET_FCT_NAMES = (
    :setFctGetTypesPlatform,
    :setFctGetVersion,
    :setFctInstantiate,
    :setFctFreeInstance,
    :setFctSetDebugLogging,
    :setFctSetupExperiment,
    :setFctEnterInitializationMode,
    :setFctExitInitializationMode,
    :setFctTerminate,
    :setFctReset,
    :setFctGetReal,
    :setFctGetInteger,
    :setFctGetBoolean,
    :setFctGetString,
    :setFctSetReal,
    :setFctSetInteger,
    :setFctSetBoolean,
    :setFctSetString,
    :setFctSetTime,
    :setFctSetContinuousStates,
    :setFctEnterEventMode,
    :setFctNewDiscreteStates,
    :setFctEnterContinuousTimeMode,
    :setFctCompletedIntegratorStep,
    :setFctGetDerivatives,
    :setFctGetEventIndicators,
    :setFctGetContinuousStates,
    :setFctGetNominalsOfContinuousStates,
    :setFctSetRealInputDerivatives,
    :setFctGetRealOutputDerivatives,
    :setFctDoStep,
    :setFctCancelStep,
    :setFctGetStatus,
    :setFctGetRealStatus,
    :setFctGetIntegerStatus,
    :setFctGetBooleanStatus,
    :setFctGetStringStatus,
)

# auto creating doc strings
for name in _SET_FCT_NAMES
    callback_field = Symbol("c", replace(String(name), "setFct" => ""))
    doc = """
        $(name)(fmu, fun)

    Register `fun` as the FMI 2 callback stored in `fmu.$(callback_field)`.
    """
    @eval @doc $doc $name
end
