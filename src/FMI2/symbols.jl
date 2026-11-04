#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

"""
    FMI2Symbols

Version-independent names for FMI 2 types, constants and functions. `FMI3Symbols` exports the same
names for FMI 3, so code can be written for both FMI versions, e.g.:

```julia
const FMI_VERSION = 3
const FMISymbols = FMI_VERSION == 2 ? FMIExport.FMI2Symbols : FMIExport.FMI3Symbols
using .FMISymbols
```
"""
module FMI2Symbols

using FMIBase: FMU2, fmiValueReference
using FMIBase.FMICore:
    fmi2Real,
    fmi2Integer,
    fmi2Boolean,
    fmi2True,
    fmi2False,
    fmi2Component,
    fmi2StatusOK,
    fmi2StatusWarning,
    fmi2StatusError,
    fmi2VariabilityTunable,
    fmi2InitialExact,
    fmi2GetReal!,
    fmi2SetReal,
    fmi2GetDerivatives!,
    fmi2SetTime,
    fmi2SetContinuousStates
import ..FMIExport

# types and constants
const fmiReal = fmi2Real
const fmiInteger = fmi2Integer
const fmiBoolean = fmi2Boolean
const fmiTrue = fmi2True
const fmiFalse = fmi2False
const fmiComponent = fmi2Component
const fmiStatusOK = fmi2StatusOK
const fmiStatusWarning = fmi2StatusWarning
const fmiStatusError = fmi2StatusError
const fmiVariabilityTunable = fmi2VariabilityTunable
const fmiInitialExact = fmi2InitialExact

# FMU constructors
const createFMU = FMIExport.createFMU2
const createFMUSimple = FMIExport.createFMU2Simple
const createFMUEmbedded = FMIExport.createFMU2Embedded

# calls of the C functions behind function pointers
const fmiGetReal! = fmi2GetReal!
const fmiSetReal = fmi2SetReal
const fmiGetDerivatives! = fmi2GetDerivatives!
const fmiSetTime = fmi2SetTime
const fmiSetContinuousStates = fmi2SetContinuousStates

# function pointers to the C functions
cGetReal(fmu::FMU2) = fmu.cGetReal
cSetReal(fmu::FMU2) = fmu.cSetReal
cGetDerivatives(fmu::FMU2) = fmu.cGetDerivatives

# capability flags that are named differently in FMI 2
const CAPABILITY_NAMES = Dict(
    :canGetAndSetFMUState => :canGetAndSetFMUstate,
    :canSerializeFMUState => :canSerializeFMUstate,
    :providesDirectionalDerivatives => :providesDirectionalDerivative,
)

"""
    setCapabilities!(capabilities; kwargs...)

Set the capability flags of the `ModelExchange` or `CoSimulation` part of a model description by
their FMI 3 names, e.g. `setCapabilities!(fmu.modelDescription.modelExchange; canGetAndSetFMUState = false)`.
"""
function setCapabilities!(capabilities; kwargs...)
    for (name, value) in kwargs
        setproperty!(capabilities, get(CAPABILITY_NAMES, name, name), value)
    end
    return capabilities
end

export fmiReal, fmiInteger, fmiBoolean, fmiTrue, fmiFalse, fmiComponent, fmiValueReference
export fmiStatusOK, fmiStatusWarning, fmiStatusError, fmiVariabilityTunable, fmiInitialExact
export createFMU, createFMUSimple, createFMUEmbedded
export fmiGetReal!, fmiSetReal, fmiGetDerivatives!, fmiSetTime, fmiSetContinuousStates
export cGetReal, cSetReal, cGetDerivatives, setCapabilities!

end # module FMI2Symbols
