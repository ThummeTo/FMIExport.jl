#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

# [Note] `@cfunction($fun, ...)` returns a `CFunction` object that owns the code behind its pointer,
#        the code is freed when the object is garbage collected. Therefore, the `CFunction` objects
#        are stored as long as the FMU (that holds the pointers) exists.
const FMU_CFUNCTIONS = WeakKeyDict{FMU,Vector{Base.CFunction}}()

# stores `c_fun` for the lifetime of `fmu` and sets its pointer as the FMU function `field`
function storeCFunction!(fmu::FMU, field::Symbol, c_fun::Base.CFunction)
    push!(get!(Vector{Base.CFunction}, FMU_CFUNCTIONS, fmu), c_fun)
    setproperty!(fmu, field, c_fun.ptr)
    return c_fun.ptr
end

function setFctGetTypesPlatform(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2String, ())
    storeCFunction!(fmu, :cGetTypesPlatform, c_fun)
end
export setFctGetTypesPlatform

function setFctGetVersion(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2String, ())
    storeCFunction!(fmu, :cGetVersion, c_fun)
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
    storeCFunction!(fmu, :cInstantiate, c_fun)
end
export setFctInstantiate

function setFctFreeInstance(fmu::FMU2, fun)
    c_fun = @cfunction($fun, Cvoid, (fmi2Component,))
    storeCFunction!(fmu, :cFreeInstance, c_fun)
end
export setFctFreeInstance

function setFctSetDebugLogging(fmu::FMU2, fun)
    c_fun =
        @cfunction($fun, fmi2Status, (fmi2Component, fmi2Boolean, Csize_t, Ptr{fmi2String}))
    storeCFunction!(fmu, :cSetDebugLogging, c_fun)
end
export setFctSetDebugLogging

function setFctSetupExperiment(fmu::FMU2, fun)
    c_fun = @cfunction(
        $fun,
        fmi2Status,
        (fmi2Component, fmi2Boolean, fmi2Real, fmi2Real, fmi2Boolean, fmi2Real)
    )
    storeCFunction!(fmu, :cSetupExperiment, c_fun)
end
export setFctSetupExperiment

function setFctEnterInitializationMode(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component,))
    storeCFunction!(fmu, :cEnterInitializationMode, c_fun)
end
export setFctEnterInitializationMode

function setFctExitInitializationMode(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component,))
    storeCFunction!(fmu, :cExitInitializationMode, c_fun)
end
export setFctExitInitializationMode

function setFctTerminate(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component,))
    storeCFunction!(fmu, :cTerminate, c_fun)
end
export setFctTerminate

function setFctReset(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component,))
    storeCFunction!(fmu, :cReset, c_fun)
end
export setFctReset

function setFctGetReal(fmu::FMU2, fun)
    c_fun = @cfunction(
        $fun,
        fmi2Status,
        (fmi2Component, Ptr{fmi2ValueReference}, Csize_t, Ptr{fmi2Real})
    )
    storeCFunction!(fmu, :cGetReal, c_fun)
end
export setFctGetReal

function setFctGetInteger(fmu::FMU2, fun)
    c_fun = @cfunction(
        $fun,
        fmi2Status,
        (fmi2Component, Ptr{fmi2ValueReference}, Csize_t, Ptr{fmi2Integer})
    )
    storeCFunction!(fmu, :cGetInteger, c_fun)
end
export setFctGetInteger

function setFctGetBoolean(fmu::FMU2, fun)
    c_fun = @cfunction(
        $fun,
        fmi2Status,
        (fmi2Component, Ptr{fmi2ValueReference}, Csize_t, Ptr{fmi2Boolean})
    )
    storeCFunction!(fmu, :cGetBoolean, c_fun)
end
export setFctGetBoolean

function setFctGetString(fmu::FMU2, fun)
    c_fun = @cfunction(
        $fun,
        fmi2Status,
        (fmi2Component, Ptr{fmi2ValueReference}, Csize_t, Ptr{fmi2String})
    )
    storeCFunction!(fmu, :cGetString, c_fun)
end
export setFctGetString

function setFctSetReal(fmu::FMU2, fun)
    c_fun = @cfunction(
        $fun,
        fmi2Status,
        (fmi2Component, Ptr{fmi2ValueReference}, Csize_t, Ptr{fmi2Real})
    )
    storeCFunction!(fmu, :cSetReal, c_fun)
end
export setFctSetReal

function setFctSetInteger(fmu::FMU2, fun)
    c_fun = @cfunction(
        $fun,
        fmi2Status,
        (fmi2Component, Ptr{fmi2ValueReference}, Csize_t, Ptr{fmi2Integer})
    )
    storeCFunction!(fmu, :cSetInteger, c_fun)
end
export setFctSetInteger

function setFctSetBoolean(fmu::FMU2, fun)
    c_fun = @cfunction(
        $fun,
        fmi2Status,
        (fmi2Component, Ptr{fmi2ValueReference}, Csize_t, Ptr{fmi2Boolean})
    )
    storeCFunction!(fmu, :cSetBoolean, c_fun)
end
export setFctSetBoolean

function setFctSetString(fmu::FMU2, fun)
    c_fun = @cfunction(
        $fun,
        fmi2Status,
        (fmi2Component, Ptr{fmi2ValueReference}, Csize_t, Ptr{fmi2String})
    )
    storeCFunction!(fmu, :cSetString, c_fun)
end
export setFctSetString

function setFctSetTime(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component, fmi2Real))
    storeCFunction!(fmu, :cSetTime, c_fun)
end
export setFctSetTime

function setFctSetContinuousStates(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component, Ptr{fmi2Real}, Csize_t))
    storeCFunction!(fmu, :cSetContinuousStates, c_fun)
end
export setFctSetContinuousStates

function setFctEnterEventMode(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component,))
    storeCFunction!(fmu, :cEnterEventMode, c_fun)
end
export setFctEnterEventMode

function setFctNewDiscreteStates(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component, Ptr{fmi2EventInfo}))
    storeCFunction!(fmu, :cNewDiscreteStates, c_fun)
end
export setFctNewDiscreteStates

function setFctEnterContinuousTimeMode(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component,))
    storeCFunction!(fmu, :cEnterContinuousTimeMode, c_fun)
end
export setFctEnterContinuousTimeMode

function setFctCompletedIntegratorStep(fmu::FMU2, fun)
    c_fun = @cfunction(
        $fun,
        fmi2Status,
        (fmi2Component, fmi2Boolean, Ptr{fmi2Boolean}, Ptr{fmi2Boolean})
    )
    storeCFunction!(fmu, :cCompletedIntegratorStep, c_fun)
end
export setFctCompletedIntegratorStep

function setFctGetDerivatives(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component, Ptr{fmi2Real}, Csize_t))
    storeCFunction!(fmu, :cGetDerivatives, c_fun)
end
export setFctGetDerivatives

function setFctGetEventIndicators(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component, Ptr{fmi2Real}, Csize_t))
    storeCFunction!(fmu, :cGetEventIndicators, c_fun)
end
export setFctGetEventIndicators

function setFctGetContinuousStates(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component, Ptr{fmi2Real}, Csize_t))
    storeCFunction!(fmu, :cGetContinuousStates, c_fun)
end
export setFctGetContinuousStates

function setFctGetNominalsOfContinuousStates(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component, Ptr{fmi2Real}, Csize_t))
    storeCFunction!(fmu, :cGetNominalsOfContinuousStates, c_fun)
end
export setFctGetNominalsOfContinuousStates

function setFctSetRealInputDerivatives(fmu::FMU2, fun)
    c_fun = @cfunction(
        $fun,
        fmi2Status,
        (fmi2Component, Ptr{fmi2ValueReference}, Csize_t, Ptr{fmi2Integer}, Ptr{fmi2Real})
    )
    storeCFunction!(fmu, :cSetRealInputDerivatives, c_fun)
end
export setFctSetRealInputDerivatives

function setFctGetRealOutputDerivatives(fmu::FMU2, fun)
    c_fun = @cfunction(
        $fun,
        fmi2Status,
        (fmi2Component, Ptr{fmi2ValueReference}, Csize_t, Ptr{fmi2Integer}, Ptr{fmi2Real})
    )
    storeCFunction!(fmu, :cGetRealOutputDerivatives, c_fun)
end
export setFctGetRealOutputDerivatives

function setFctDoStep(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component, fmi2Real, fmi2Real, fmi2Boolean))
    storeCFunction!(fmu, :cDoStep, c_fun)
end
export setFctDoStep

function setFctCancelStep(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component,))
    storeCFunction!(fmu, :cCancelStep, c_fun)
end
export setFctCancelStep

function setFctGetStatus(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component, fmi2StatusKind, Ptr{fmi2Status}))
    storeCFunction!(fmu, :cGetStatus, c_fun)
end
export setFctGetStatus

function setFctGetRealStatus(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component, fmi2StatusKind, Ptr{fmi2Real}))
    storeCFunction!(fmu, :cGetRealStatus, c_fun)
end
export setFctGetRealStatus

function setFctGetIntegerStatus(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component, fmi2StatusKind, Ptr{fmi2Integer}))
    storeCFunction!(fmu, :cGetIntegerStatus, c_fun)
end
export setFctGetIntegerStatus

function setFctGetBooleanStatus(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component, fmi2StatusKind, Ptr{fmi2Boolean}))
    storeCFunction!(fmu, :cGetBooleanStatus, c_fun)
end
export setFctGetBooleanStatus

function setFctGetStringStatus(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component, fmi2StatusKind, Ptr{fmi2String}))
    storeCFunction!(fmu, :cGetStringStatus, c_fun)
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
