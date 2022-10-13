#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#
using FMICore: fmi2ScalarVariable


md = fmi2CreateModelDescription()
var = fmi2ModelDescriptionAddRealStateAndDerivative(md, "mass.s")
@test typeof(var) == Tuple{fmi2ScalarVariable, fmi2ScalarVariable} 
@test var[1].name == "mass.s"
@test var[1].valueReference == 1
@test var[2].name == "der(mass.s)"
@test var[2].valueReference == 2

var = fmi2ModelDescriptionAddRealStateAndDerivative(md, "mass.v")
@test typeof(var) == Tuple{fmi2ScalarVariable, fmi2ScalarVariable}
@test var[1].name == "mass.v"
@test var[1].valueReference == 3
@test var[2].name == "der(mass.v)"
@test var[2].valueReference == 4

var = fmi2ModelDescriptionAddRealOutput(md, "mass.f")
@test typeof(var) ==fmi2ScalarVariable
@test var.name == "mass.f"
@test var.valueReference == 5
