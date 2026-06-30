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
