#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

using FMIExport.FMICore: fmi2ScalarVariable

named_fmu = createFMU2("Mass"; type = FMIExport.FMICore.fmi2TypeCoSimulation)
@test named_fmu.modelDescription.modelName == "Mass"
addModelExchange(named_fmu)
@test named_fmu.modelDescription.modelExchange.modelIdentifier == "Mass"
addCoSimulation(named_fmu)
@test named_fmu.modelDescription.coSimulation.modelIdentifier == "Mass"

fmu = createFMU2(; type = FMIExport.FMICore.fmi2TypeCoSimulation)
md = createModelDescription(fmu)
var = addRealStateAndDerivative(md, "mass.s")
@test typeof(var) == Tuple{fmi2ScalarVariable,fmi2ScalarVariable}
@test var[1].name == "mass.s"
@test var[1].valueReference == 1
@test var[2].name == "der(mass.s)"
@test var[2].valueReference == 2

var = addRealStateAndDerivative(md, "mass.v")
@test typeof(var) == Tuple{fmi2ScalarVariable,fmi2ScalarVariable}
@test var[1].name == "mass.v"
@test var[1].valueReference == 3
@test var[2].name == "der(mass.v)"
@test var[2].valueReference == 4

var = addRealOutput(md, "mass.f")
@test typeof(var) == fmi2ScalarVariable
@test var.name == "mass.f"
@test var.valueReference == 5

cs = addCoSimulation(md, "mass_cs")
@test cs.modelIdentifier == "mass_cs"
@test cs.canHandleVariableCommunicationStepSize == true
@test cs.canGetAndSetFMUstate == false
@test cs.canSerializeFMUstate == false
@test cs.providesDirectionalDerivative == false

cs = addCoSimulation(fmu, "simple_cs"; canInterpolateInputs = false)
@test fmu.type == FMIExport.FMICore.fmi2TypeCoSimulation
@test fmu.modelDescription.coSimulation === cs
@test cs.modelIdentifier == "simple_cs"
@test cs.canInterpolateInputs == false
