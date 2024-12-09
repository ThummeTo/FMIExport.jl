#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

module FMIExport

# using FMICore
# using FMICore: FMU2, FMU2Component, fmi2ModelDescription, fmi2ValueReference, fmi2Component, fmi2ComponentEnvironment, fmi2Status, fmi2EventInfo
# using FMICore: fmi2Causality, fmi2CausalityOutput, fmi2CausalityInput
# using FMICore: fmi2ScalarVariable, fmi2Variability, fmi2Initial, FMI2_SCALAR_VARIABLE_ATTRIBUTE_STRUCT
# using FMICore: fmi2RealAttributesExt, fmi2IntegerAttributesExt, fmi2BooleanAttributesExt, fmi2StringAttributesExt, fmi2EnumerationAttributesExt
# using FMICore: fmi2VariableDependency, fmi2Unknown, fmi2DependencyKind
# using FMICore: fmi2VariableNamingConventionStructured
# using FMICore: fmi2CausalityToString, fmi2VariabilityToString, fmi2InitialToString
# using FMICore: fmi2String, fmi2Boolean, fmi2Integer, fmi2Real
# using FMICore: fmi2Type, fmi2TypeModelExchange, fmi2TypeCoSimulation
# using FMICore: fmi2CallbackFunctions
# using FMICore: fmi2StatusOK, fmi2StatusWarning, fmi2StatusError
# using FMICore: fmi2True, fmi2False
# using FMICore: fmi2ModelDescriptionModelExchange, fmi2ModelDescriptionCoSimulation
using FMIBase
using FMIBase.FMICore
using FMIBase.FMICore: FMI2_SCALAR_VARIABLE_ATTRIBUTE_STRUCT

include("FMI2_md.jl")
export fmi2CreateModelDescription
export fmi2ModelDescriptionAddEvent
export fmi2GetIndexOfScalarVariable
export fmi2ModelDescriptionAddRealStateAndDerivative, fmi2ModelDescriptionAddIntegerDiscreteState
export fmi2ModelDescriptionAddRealState, fmi2ModelDescriptionAddRealDerivative, fmi2ModelDescriptionAddRealInput, fmi2ModelDescriptionAddRealOutput, fmi2ModelDescriptionAddRealParameter, fmi2ModelDescriptionAddEventIndicator
export fmi2ModelDescriptionAddModelVariable, fmi2ModelDescriptionAddModelStructureOutputs, fmi2ModelDescriptionAddModelStructureDerivatives, fmi2ModelDescriptionAddModelStructureInitialUnknowns

export fmi2Create, fmi2CreateEmbedded
export fmi2AddIntegerDiscreteState
export fmi2AddRealStateAndDerivative, fmi2AddStateAndDerivative 
export fmi2AddRealOutput, fmi2AddOutput 
export fmi2AddRealInput, fmi2AddInput 
export fmi2AddRealParameter, fmi2AddParameter, fmi2AddEventIndicator

export fmi2SetFctGetTypesPlatform, fmi2SetFctGetVersion
export fmi2SetFctInstantiate, fmi2SetFctFreeInstance, fmi2SetFctSetDebugLogging, fmi2SetFctSetupExperiment, fmi2SetFctEnterInitializationMode, fmi2SetFctExitInitializationMode
export fmi2SetFctTerminate, fmi2SetFctReset
export fmi2SetFctGetReal, fmi2SetFctGetInteger, fmi2SetFctGetBoolean, fmi2SetFctGetString, fmi2SetFctSetReal, fmi2SetFctSetInteger, fmi2SetFctSetBoolean, fmi2SetFctSetString
export fmi2SetFctSetTime, fmi2SetFctSetContinuousStates, fmi2SetFctEnterEventMode, fmi2SetFctNewDiscreteStates, fmi2SetFctEnterContinuousTimeMode, fmi2SetFctCompletedIntegratorStep
export fmi2SetFctGetDerivatives, fmi2SetFctGetEventIndicators, fmi2SetFctGetContinuousStates, fmi2SetFctGetNominalsOfContinuousStates

export fmi2ModelDescriptionAddModelExchange

include("ANN.jl")

include("FMI2_simple.jl")
export fmi2CreateSimple 

function fmi2SetFctGetTypesPlatform(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2String, ())
    fmu.cGetTypesPlatform = c_fun.ptr
end

function fmi2SetFctGetVersion(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2String, ())
    fmu.cGetVersion = c_fun.ptr
end

function fmi2SetFctInstantiate(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Component, (fmi2String, fmi2Type, fmi2String, fmi2String, Ptr{fmi2CallbackFunctions}, fmi2Boolean, fmi2Boolean))
    fmu.cInstantiate = c_fun.ptr
end

function fmi2SetFctFreeInstance(fmu::FMU2, fun)
    c_fun = @cfunction($fun, Cvoid, (fmi2Component,))
    fmu.cFreeInstance = c_fun.ptr
end

function fmi2SetFctSetDebugLogging(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component, fmi2Boolean, Csize_t, Ptr{fmi2String}))
    fmu.cSetDebugLogging = c_fun.ptr
end

function fmi2SetFctSetupExperiment(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component, fmi2Boolean, fmi2Real, fmi2Real, fmi2Boolean, fmi2Real))
    fmu.cSetupExperiment = c_fun.ptr
end

function fmi2SetFctEnterInitializationMode(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component,))
    fmu.cEnterInitializationMode = c_fun.ptr
end

function fmi2SetFctExitInitializationMode(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component,))
    fmu.cExitInitializationMode= c_fun.ptr
end

function fmi2SetFctTerminate(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component,))
    fmu.cTerminate = c_fun.ptr
end

function fmi2SetFctReset(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component,))
    fmu.cReset = c_fun.ptr
end

function fmi2SetFctGetReal(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component, Ptr{fmi2ValueReference}, Csize_t, Ptr{fmi2Real}))
    fmu.cGetReal = c_fun.ptr
end

function fmi2SetFctGetInteger(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component, Ptr{fmi2ValueReference}, Csize_t, Ptr{fmi2Integer}))
    fmu.cGetInteger = c_fun.ptr
end

function fmi2SetFctGetBoolean(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component, Ptr{fmi2ValueReference}, Csize_t, Ptr{fmi2Boolean}))
    fmu.cGetBoolean = c_fun.ptr
end

function fmi2SetFctGetString(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component, Ptr{fmi2ValueReference}, Csize_t, Ptr{fmi2String}))
    fmu.cGetString = c_fun.ptr
end

function fmi2SetFctSetReal(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component, Ptr{fmi2ValueReference}, Csize_t, Ptr{fmi2Real}))
    fmu.cSetReal = c_fun.ptr
end

function fmi2SetFctSetInteger(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component, Ptr{fmi2ValueReference}, Csize_t, Ptr{fmi2Integer}))
    fmu.cSetInteger = c_fun.ptr
end

function fmi2SetFctSetBoolean(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component, Ptr{fmi2ValueReference}, Csize_t, Ptr{fmi2Boolean}))
    fmu.cSetBoolean = c_fun.ptr
end

function fmi2SetFctSetString(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component, Ptr{fmi2ValueReference}, Csize_t, Ptr{fmi2String}))
    fmu.cSetString = c_fun.ptr
end

function fmi2SetFctSetTime(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component, fmi2Real))
    fmu.cSetTime = c_fun.ptr
end

function fmi2SetFctSetContinuousStates(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component, Ptr{fmi2Real}, Csize_t))
    fmu.cSetContinuousStates = c_fun.ptr
end

function fmi2SetFctEnterEventMode(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component,))
    fmu.cEnterEventMode = c_fun.ptr
end

function fmi2SetFctNewDiscreteStates(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component, Ptr{fmi2EventInfo}))
    fmu.cNewDiscreteStates = c_fun.ptr
end

function fmi2SetFctEnterContinuousTimeMode(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component,))
    fmu.cEnterContinuousTimeMode = c_fun.ptr
end

function fmi2SetFctCompletedIntegratorStep(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component, fmi2Boolean, Ptr{fmi2Boolean}, Ptr{fmi2Boolean}))
    fmu.cCompletedIntegratorStep = c_fun.ptr
end

function fmi2SetFctGetDerivatives(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component, Ptr{fmi2Real}, Csize_t))
    fmu.cGetDerivatives = c_fun.ptr
end

function fmi2SetFctGetEventIndicators(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component, Ptr{fmi2Real}, Csize_t))
    fmu.cGetEventIndicators = c_fun.ptr
end

function fmi2SetFctGetContinuousStates(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component, Ptr{fmi2Real}, Csize_t))
    fmu.cGetContinuousStates = c_fun.ptr
end

function fmi2SetFctGetNominalsOfContinuousStates(fmu::FMU2, fun)
    c_fun = @cfunction($fun, fmi2Status, (fmi2Component, Ptr{fmi2Real}, Csize_t))
    fmu.cGetNominalsOfContinuousStates = c_fun.ptr
end

""" 
ToDo
"""
function fmi2Create(modelName::String=""; type=fmi2TypeModelExchange)
    fmu = FMU2()
    
    fmu.modelName = modelName
    fmu.isZeroState = false
    fmu.type = type
    fmu.modelDescription = fmi2CreateModelDescription()
    fmu.fmuResourceLocation = pwd()
    
    return fmu
end

""" 
ToDo
"""
function fmi2CreateEmbedded(fmu::FMU; type=fmi2TypeModelExchange)
    global FMIBUILD_FMU

    FMIBUILD_FMU = fmu

    # store function pointers to embedded FMU
    fmu.cFunctionPtrs["EMBEDDED_fmi2Instantiate"] = fmu.cInstantiate
    fmu.cFunctionPtrs["EMBEDDED_fmi2FreeInstance"] = fmu.cFreeInstance
    
    # a special instantiation function for embedded FMUs (enables FMI.jl interface)
    fmi2SetFctInstantiate(fmu, embedded_fmi2Instantiate) 
    
    # a special function for simple instance release (enables FMI.jl interface)
    fmi2SetFctFreeInstance(fmu, embedded_fmi2FreeInstance) 

    return fmu
end

function fmi2AddRealStateAndDerivative(fmu, stateName; kwargs...)
    fmi2ModelDescriptionAddRealStateAndDerivative(fmu.modelDescription, stateName; kwargs...)
end
fmi2AddStateAndDerivative = fmi2AddRealStateAndDerivative

function fmi2AddIntegerDiscreteState(fmu, stateName; kwargs...)
    fmi2ModelDescriptionAddIntegerDiscreteState(fmu.modelDescription, stateName; kwargs...)
end

function fmi2AddRealOutput(fmu, name; kwargs...)
    fmi2ModelDescriptionAddRealOutput(fmu.modelDescription, name; kwargs...)
end
fmi2AddOutput = fmi2AddRealOutput

function fmi2AddRealInput(fmu, name; kwargs...)
    fmi2ModelDescriptionAddRealInput(fmu.modelDescription, name; kwargs...)
end
fmi2AddInput = fmi2AddRealInput

function fmi2AddRealParameter(fmu, name; kwargs...)
    fmi2ModelDescriptionAddRealParameter(fmu.modelDescription, name; kwargs...)
end
fmi2AddParameter = fmi2AddRealParameter

function fmi2AddEventIndicator(fmu)
    fmi2ModelDescriptionAddEventIndicator(fmu.modelDescription)
end

"""
ToDo
"""
function fmi2Check(fmu::FMU2)
    return true
end

end # module
