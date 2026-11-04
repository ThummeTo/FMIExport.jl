#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

using FMIExport.FMICore: fmi3VariableFloat64, fmi3VariableInt32, fmi3ValueReference

named_fmu = createFMU3("Mass"; type = FMIExport.FMICore.fmi3TypeCoSimulation)
@test named_fmu.modelDescription.modelName == "Mass"
@test named_fmu.modelDescription.fmiVersion == "3.0"
addModelExchange(named_fmu)
@test named_fmu.modelDescription.modelExchange.modelIdentifier == "Mass"
addCoSimulation(named_fmu)
@test named_fmu.modelDescription.coSimulation.modelIdentifier == "Mass"

fmu = createFMU3(; type = FMIExport.FMICore.fmi3TypeCoSimulation)
md = fmu.modelDescription

# the independent variable is required in FMI 3
@test md.modelVariables[1].name == "time"
@test md.modelVariables[1].valueReference == 0
@test md.modelVariables[1].causality == FMIExport.FMICore.fmi3CausalityIndependent

var = addRealStateAndDerivative(md, "mass.s")
@test typeof(var) == Tuple{fmi3VariableFloat64,fmi3VariableFloat64}
@test var[1].name == "mass.s"
@test var[1].valueReference == 1
@test var[2].name == "der(mass.s)"
@test var[2].valueReference == 2
@test var[2].derivative == 1

var = addRealStateAndDerivative(md, "mass.v")
@test var[1].valueReference == 3
@test var[2].valueReference == 4
@test md.stateValueReferences == [1, 3]
@test md.derivativeValueReferences == [2, 4]
@test [d.index for d in md.modelStructure.continuousStateDerivatives] == [2, 4]

var = addRealOutput(md, "mass.f")
@test typeof(var) == fmi3VariableFloat64
@test var.name == "mass.f"
@test var.valueReference == 5
@test var.causality == FMIExport.FMICore.fmi3CausalityOutput
@test [d.index for d in md.modelStructure.outputs] == [5]

var = addIntegerDiscreteState(md, "mass.n")
@test typeof(var) == fmi3VariableInt32
@test md.discreteStateValueReferences == [6]

var = addEventIndicator(md)
@test md.numberOfEventIndicators == 1
@test md.eventIndicatorValueReferences == [var.valueReference]
@test [d.index for d in md.modelStructure.eventIndicators] == [var.valueReference]

cs = addCoSimulation(md, "mass_cs")
@test cs.modelIdentifier == "mass_cs"
@test cs.canHandleVariableCommunicationStepSize == true
@test cs.canGetAndSetFMUState == false
@test cs.canSerializeFMUState == false
@test cs.providesDirectionalDerivatives == false
@test cs.hasEventMode == false

# automatic value references are the smallest unused ones, also if the largest one is used
# (e.g. by Dymola for `time`), explicit value references must be unique
md = createFMU3().modelDescription # `time` has value reference 0
addRealOutput(md, "z"; valueReference = typemax(fmi3ValueReference))
@test addRealOutput(md, "a").valueReference == 1
@test addRealOutput(md, "b").valueReference == 2
@test_throws ArgumentError addRealOutput(md, "c"; valueReference = fmi3ValueReference(1))
@test length(md.modelVariables) == 4
