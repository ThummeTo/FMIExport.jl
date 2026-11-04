#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

function setFctGetVersion(fmu::FMU3, fun)
    c_fun = @cfunction($fun, fmi3String, ())
    storeCFunction!(fmu, :cGetVersion, c_fun)
end

function setFctInstantiateModelExchange(fmu::FMU3, fun)
    c_fun = @cfunction(
        $fun,
        fmi3Instance,
        (
            fmi3String,
            fmi3String,
            fmi3String,
            fmi3Boolean,
            fmi3Boolean,
            fmi3InstanceEnvironment,
            Ptr{Cvoid},
        )
    )
    storeCFunction!(fmu, :cInstantiateModelExchange, c_fun)
end
export setFctInstantiateModelExchange

function setFctInstantiateCoSimulation(fmu::FMU3, fun)
    c_fun = @cfunction(
        $fun,
        fmi3Instance,
        (
            fmi3String,
            fmi3String,
            fmi3String,
            fmi3Boolean,
            fmi3Boolean,
            fmi3Boolean,
            fmi3Boolean,
            Ptr{fmi3ValueReference},
            Csize_t,
            fmi3InstanceEnvironment,
            Ptr{Cvoid},
            Ptr{Cvoid},
        )
    )
    storeCFunction!(fmu, :cInstantiateCoSimulation, c_fun)
end
export setFctInstantiateCoSimulation

function setFctFreeInstance(fmu::FMU3, fun)
    c_fun = @cfunction($fun, Cvoid, (fmi3Instance,))
    storeCFunction!(fmu, :cFreeInstance, c_fun)
end

function setFctSetDebugLogging(fmu::FMU3, fun)
    c_fun =
        @cfunction($fun, fmi3Status, (fmi3Instance, fmi3Boolean, Csize_t, Ptr{fmi3String}))
    storeCFunction!(fmu, :cSetDebugLogging, c_fun)
end

function setFctEnterInitializationMode(fmu::FMU3, fun)
    c_fun = @cfunction(
        $fun,
        fmi3Status,
        (fmi3Instance, fmi3Boolean, fmi3Float64, fmi3Float64, fmi3Boolean, fmi3Float64)
    )
    storeCFunction!(fmu, :cEnterInitializationMode, c_fun)
end

# functions with signature `fmi3Status fun(fmi3Instance)`
for (name, field) in (
    (:setFctExitInitializationMode, :cExitInitializationMode),
    (:setFctEnterEventMode, :cEnterEventMode),
    (:setFctTerminate, :cTerminate),
    (:setFctReset, :cReset),
    (:setFctEnterConfigurationMode, :cEnterConfigurationMode),
    (:setFctExitConfigurationMode, :cExitConfigurationMode),
    (:setFctEvaluateDiscreteStates, :cEvaluateDiscreteStates),
    (:setFctEnterContinuousTimeMode, :cEnterContinuousTimeMode),
    (:setFctEnterStepMode, :cEnterStepMode),
)
    @eval function $name(fmu::FMU3, fun)
        c_fun = @cfunction($(Expr(:$, :fun)), fmi3Status, (fmi3Instance,))
        storeCFunction!(fmu, $(QuoteNode(field)), c_fun)
    end
end
export setFctEnterConfigurationMode,
    setFctExitConfigurationMode, setFctEvaluateDiscreteStates, setFctEnterStepMode

# getters and setters `fmi3Status fun(fmi3Instance, const fmi3ValueReference[], size_t, T[], size_t)`
for type in (
    :Float32,
    :Float64,
    :Int8,
    :UInt8,
    :Int16,
    :UInt16,
    :Int32,
    :UInt32,
    :Int64,
    :UInt64,
    :Boolean,
    :String,
)
    T = Symbol("fmi3", type)
    for prefix in ("Get", "Set")
        name = Symbol("setFct", prefix, type)
        field = Symbol("c", prefix, type)
        @eval function $name(fmu::FMU3, fun)
            c_fun = @cfunction(
                $(Expr(:$, :fun)),
                fmi3Status,
                (fmi3Instance, Ptr{fmi3ValueReference}, Csize_t, Ptr{$T}, Csize_t)
            )
            storeCFunction!(fmu, $(QuoteNode(field)), c_fun)
        end
        @eval export $name
    end
end

function setFctGetBinary(fmu::FMU3, fun)
    c_fun = @cfunction(
        $fun,
        fmi3Status,
        (
            fmi3Instance,
            Ptr{fmi3ValueReference},
            Csize_t,
            Ptr{Csize_t},
            Ptr{fmi3Binary},
            Csize_t,
        )
    )
    storeCFunction!(fmu, :cGetBinary, c_fun)
end
export setFctGetBinary

function setFctSetBinary(fmu::FMU3, fun)
    c_fun = @cfunction(
        $fun,
        fmi3Status,
        (
            fmi3Instance,
            Ptr{fmi3ValueReference},
            Csize_t,
            Ptr{Csize_t},
            Ptr{fmi3Binary},
            Csize_t,
        )
    )
    storeCFunction!(fmu, :cSetBinary, c_fun)
end
export setFctSetBinary

function setFctGetNumberOfVariableDependencies(fmu::FMU3, fun)
    c_fun = @cfunction($fun, fmi3Status, (fmi3Instance, fmi3ValueReference, Ptr{Csize_t}))
    storeCFunction!(fmu, :cGetNumberOfVariableDependencies, c_fun)
end
export setFctGetNumberOfVariableDependencies

function setFctGetVariableDependencies(fmu::FMU3, fun)
    c_fun = @cfunction(
        $fun,
        fmi3Status,
        (
            fmi3Instance,
            fmi3ValueReference,
            Ptr{Csize_t},
            Ptr{fmi3ValueReference},
            Ptr{Csize_t},
            Ptr{fmi3DependencyKind},
            Csize_t,
        )
    )
    storeCFunction!(fmu, :cGetVariableDependencies, c_fun)
end
export setFctGetVariableDependencies

function setFctGetFMUState(fmu::FMU3, fun)
    c_fun = @cfunction($fun, fmi3Status, (fmi3Instance, Ptr{fmi3FMUState}))
    storeCFunction!(fmu, :cGetFMUState, c_fun)
end
export setFctGetFMUState

function setFctSetFMUState(fmu::FMU3, fun)
    c_fun = @cfunction($fun, fmi3Status, (fmi3Instance, fmi3FMUState))
    storeCFunction!(fmu, :cSetFMUState, c_fun)
end
export setFctSetFMUState

function setFctFreeFMUState(fmu::FMU3, fun)
    c_fun = @cfunction($fun, fmi3Status, (fmi3Instance, Ptr{fmi3FMUState}))
    storeCFunction!(fmu, :cFreeFMUState, c_fun)
end
export setFctFreeFMUState

function setFctSerializedFMUStateSize(fmu::FMU3, fun)
    c_fun = @cfunction($fun, fmi3Status, (fmi3Instance, fmi3FMUState, Ptr{Csize_t}))
    storeCFunction!(fmu, :cSerializedFMUStateSize, c_fun)
end
export setFctSerializedFMUStateSize

function setFctSerializeFMUState(fmu::FMU3, fun)
    c_fun =
        @cfunction($fun, fmi3Status, (fmi3Instance, fmi3FMUState, Ptr{fmi3Byte}, Csize_t))
    storeCFunction!(fmu, :cSerializeFMUState, c_fun)
end
export setFctSerializeFMUState

function setFctDeSerializeFMUState(fmu::FMU3, fun)
    c_fun = @cfunction(
        $fun,
        fmi3Status,
        (fmi3Instance, Ptr{fmi3Byte}, Csize_t, Ptr{fmi3FMUState})
    )
    storeCFunction!(fmu, :cDeSerializeFMUState, c_fun)
end
export setFctDeSerializeFMUState

for (name, field) in (
    (:setFctGetDirectionalDerivative, :cGetDirectionalDerivative),
    (:setFctGetAdjointDerivative, :cGetAdjointDerivative),
)
    @eval function $name(fmu::FMU3, fun)
        c_fun = @cfunction(
            $(Expr(:$, :fun)),
            fmi3Status,
            (
                fmi3Instance,
                Ptr{fmi3ValueReference},
                Csize_t,
                Ptr{fmi3ValueReference},
                Csize_t,
                Ptr{fmi3Float64},
                Csize_t,
                Ptr{fmi3Float64},
                Csize_t,
            )
        )
        storeCFunction!(fmu, $(QuoteNode(field)), c_fun)
    end
    @eval export $name
end

function setFctUpdateDiscreteStates(fmu::FMU3, fun)
    c_fun = @cfunction(
        $fun,
        fmi3Status,
        (
            fmi3Instance,
            Ptr{fmi3Boolean},
            Ptr{fmi3Boolean},
            Ptr{fmi3Boolean},
            Ptr{fmi3Boolean},
            Ptr{fmi3Boolean},
            Ptr{fmi3Float64},
        )
    )
    storeCFunction!(fmu, :cUpdateDiscreteStates, c_fun)
end
export setFctUpdateDiscreteStates

function setFctCompletedIntegratorStep(fmu::FMU3, fun)
    c_fun = @cfunction(
        $fun,
        fmi3Status,
        (fmi3Instance, fmi3Boolean, Ptr{fmi3Boolean}, Ptr{fmi3Boolean})
    )
    storeCFunction!(fmu, :cCompletedIntegratorStep, c_fun)
end

function setFctSetTime(fmu::FMU3, fun)
    c_fun = @cfunction($fun, fmi3Status, (fmi3Instance, fmi3Float64))
    storeCFunction!(fmu, :cSetTime, c_fun)
end

# functions with signature `fmi3Status fun(fmi3Instance, fmi3Float64[], size_t)`
for (name, field) in (
    (:setFctSetContinuousStates, :cSetContinuousStates),
    (:setFctGetContinuousStateDerivatives, :cGetContinuousStateDerivatives),
    (:setFctGetEventIndicators, :cGetEventIndicators),
    (:setFctGetContinuousStates, :cGetContinuousStates),
    (:setFctGetNominalsOfContinuousStates, :cGetNominalsOfContinuousStates),
)
    @eval function $name(fmu::FMU3, fun)
        c_fun = @cfunction(
            $(Expr(:$, :fun)),
            fmi3Status,
            (fmi3Instance, Ptr{fmi3Float64}, Csize_t)
        )
        storeCFunction!(fmu, $(QuoteNode(field)), c_fun)
    end
end
export setFctGetContinuousStateDerivatives

for (name, field) in (
    (:setFctGetNumberOfEventIndicators, :cGetNumberOfEventIndicators),
    (:setFctGetNumberOfContinuousStates, :cGetNumberOfContinuousStates),
)
    @eval function $name(fmu::FMU3, fun)
        c_fun = @cfunction($(Expr(:$, :fun)), fmi3Status, (fmi3Instance, Ptr{Csize_t}))
        storeCFunction!(fmu, $(QuoteNode(field)), c_fun)
    end
    @eval export $name
end

function setFctGetOutputDerivatives(fmu::FMU3, fun)
    c_fun = @cfunction(
        $fun,
        fmi3Status,
        (
            fmi3Instance,
            Ptr{fmi3ValueReference},
            Csize_t,
            Ptr{fmi3Int32},
            Ptr{fmi3Float64},
            Csize_t,
        )
    )
    storeCFunction!(fmu, :cGetOutputDerivatives, c_fun)
end
export setFctGetOutputDerivatives

function setFctDoStep(fmu::FMU3, fun)
    c_fun = @cfunction(
        $fun,
        fmi3Status,
        (
            fmi3Instance,
            fmi3Float64,
            fmi3Float64,
            fmi3Boolean,
            Ptr{fmi3Boolean},
            Ptr{fmi3Boolean},
            Ptr{fmi3Boolean},
            Ptr{fmi3Float64},
        )
    )
    storeCFunction!(fmu, :cDoStep, c_fun)
end

# auto creating doc strings for the FMI 3 methods
for name in names(@__MODULE__; all = true)
    if startswith(String(name), "setFct") &&
       hasmethod(getfield(@__MODULE__, name), Tuple{FMU3,Any})
        callback_field = Symbol("c", replace(String(name), "setFct" => ""))
        doc = """
            $(name)(fmu::FMU3, fun)

        Register `fun` as the FMI 3 callback stored in `fmu.$(callback_field)`.
        """
        @eval @doc $doc $name(::FMU3, ::Any)
    end
end
