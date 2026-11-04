#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

""" 
ToDo
"""
function createFMU2(modelName::String = ""; type = fmi2TypeModelExchange)
    fmu = FMU2()

    fmu.modelName = modelName
    fmu.isZeroState = false
    fmu.type = type
    fmu.modelDescription = createModelDescription(fmu)
    fmu.fmuResourceLocation = pwd()

    return fmu
end
export createFMU2

""" 
ToDo
"""
function createFMU2Embedded(fmu::FMU; type = fmi2TypeModelExchange)
    global FMIBUILD_FMU

    FMIBUILD_FMU = fmu
    fmu.type = type

    # store function pointers to embedded FMU
    fmu.cFunctionPtrs["EMBEDDED_fmi2Instantiate"] = fmu.cInstantiate
    fmu.cFunctionPtrs["EMBEDDED_fmi2FreeInstance"] = fmu.cFreeInstance

    # a special instantiation function for embedded FMUs (enables FMI.jl interface)
    setFctInstantiate(fmu, embedded_fmi2Instantiate)

    # a special function for simple instance release (enables FMI.jl interface)
    setFctFreeInstance(fmu, embedded_fmi2FreeInstance)

    return fmu
end
export createFMU2Embedded

""" 
    createFMU3(modelName=""; type=fmi3TypeModelExchange)

Create an empty FMI 3 FMU with a model description, the FMI functions are registered with the `setFct...` functions.
"""
function createFMU3(modelName::String = ""; type = fmi3TypeModelExchange)
    fmu = FMU3()

    fmu.modelName = modelName
    fmu.isZeroState = false
    fmu.type = type
    fmu.modelDescription = createModelDescription(fmu)
    fmu.fmuResourceLocation = pwd()

    return fmu
end
export createFMU3

""" 
    createFMU3Embedded(fmu::FMU3; type=fmi3TypeModelExchange)

Prepare an (imported) FMI 3 FMU for re-export, instances are tracked by FMIExport.
"""
function createFMU3Embedded(fmu::FMU3; type = fmi3TypeModelExchange)
    global FMIBUILD_FMU

    FMIBUILD_FMU = fmu
    fmu.type = type

    # store function pointers to embedded FMU
    fmu.cFunctionPtrs["EMBEDDED_fmi3InstantiateModelExchange"] =
        fmu.cInstantiateModelExchange
    fmu.cFunctionPtrs["EMBEDDED_fmi3InstantiateCoSimulation"] = fmu.cInstantiateCoSimulation
    fmu.cFunctionPtrs["EMBEDDED_fmi3FreeInstance"] = fmu.cFreeInstance

    # special instantiation functions for embedded FMUs (enables FMI.jl interface)
    if fmu.cInstantiateModelExchange != C_NULL
        setFctInstantiateModelExchange(fmu, embedded_fmi3InstantiateModelExchange)
    end
    if fmu.cInstantiateCoSimulation != C_NULL
        setFctInstantiateCoSimulation(fmu, embedded_fmi3InstantiateCoSimulation)
    end

    # a special function for simple instance release (enables FMI.jl interface)
    setFctFreeInstance(fmu, embedded_fmi3FreeInstance)

    return fmu
end
export createFMU3Embedded
