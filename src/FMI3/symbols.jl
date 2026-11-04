#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

"""
    FMI3Symbols

Version-independent names for FMI 3 types, constants and functions. `FMI2Symbols` exports the same
names for FMI 2, so code can be written for both FMI versions, e.g.:

```julia
const FMI_VERSION = 3
const FMISymbols = FMI_VERSION == 2 ? FMIExport.FMI2Symbols : FMIExport.FMI3Symbols
using .FMISymbols
```
"""
module FMI3Symbols

using FMIBase: FMU3, fmiValueReference
using FMIBase.FMICore:
    fmi3Float64,
    fmi3Int32,
    fmi3Boolean,
    fmi3True,
    fmi3False,
    fmi3Instance,
    fmi3StatusOK,
    fmi3StatusWarning,
    fmi3StatusError,
    fmi3VariabilityTunable,
    fmi3InitialExact,
    fmi3GetFloat64!,
    fmi3SetFloat64,
    fmi3GetContinuousStateDerivatives!,
    fmi3SetTime,
    fmi3SetContinuousStates
import ..FMIExport

# types and constants
const fmiReal = fmi3Float64
const fmiInteger = fmi3Int32
const fmiBoolean = fmi3Boolean
const fmiTrue = fmi3True
const fmiFalse = fmi3False
const fmiComponent = fmi3Instance
const fmiStatusOK = fmi3StatusOK
const fmiStatusWarning = fmi3StatusWarning
const fmiStatusError = fmi3StatusError
const fmiVariabilityTunable = fmi3VariabilityTunable
const fmiInitialExact = fmi3InitialExact

# FMU constructors
const createFMU = FMIExport.createFMU3
const createFMUSimple = FMIExport.createFMU3Simple
const createFMUEmbedded = FMIExport.createFMU3Embedded

# calls of the C functions behind function pointers,
# the getter and setter have an additional argument for the number of values (equals `nvr` for scalar variables)
fmiGetReal!(cfunc, c, vr, nvr, value) = fmi3GetFloat64!(cfunc, c, vr, nvr, value, nvr)
fmiSetReal(cfunc, c, vr, nvr, value) = fmi3SetFloat64(cfunc, c, vr, nvr, value, nvr)
const fmiGetDerivatives! = fmi3GetContinuousStateDerivatives!
const fmiSetTime = fmi3SetTime
const fmiSetContinuousStates = fmi3SetContinuousStates

# function pointers to the C functions
cGetReal(fmu::FMU3) = fmu.cGetFloat64
cSetReal(fmu::FMU3) = fmu.cSetFloat64
cGetDerivatives(fmu::FMU3) = fmu.cGetContinuousStateDerivatives

"""
    setCapabilities!(capabilities; kwargs...)

Set the capability flags of the `ModelExchange` or `CoSimulation` part of a model description,
e.g. `setCapabilities!(fmu.modelDescription.modelExchange; canGetAndSetFMUState = false)`.
"""
function setCapabilities!(capabilities; kwargs...)
    for (name, value) in kwargs
        setproperty!(capabilities, name, value)
    end
    return capabilities
end

export fmiReal, fmiInteger, fmiBoolean, fmiTrue, fmiFalse, fmiComponent, fmiValueReference
export fmiStatusOK, fmiStatusWarning, fmiStatusError, fmiVariabilityTunable, fmiInitialExact
export createFMU, createFMUSimple, createFMUEmbedded
export fmiGetReal!, fmiSetReal, fmiGetDerivatives!, fmiSetTime, fmiSetContinuousStates
export cGetReal, cSetReal, cGetDerivatives, setCapabilities!

end # module FMI3Symbols
