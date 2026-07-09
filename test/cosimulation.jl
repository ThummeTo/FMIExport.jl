#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

import OrdinaryDiffEqTsit5: Tsit5

FC = FMIExport.FMICore

init() = (0.0, [1.0], [2.0], [], [], [])
evalf(t, xc, xcdot, xd, u, p, eventMode) = (xc, [2.0], xd, p)
outf(t, xc, xcdot, xd, u, p) = xc
eventf(t, xc, xcdot, xd, u, p) = Float64[]
solverf() = Tsit5()

fmu = createFMU2Simple(
    initializationFct = init,
    evaluationFct = evalf,
    outputFct = outf,
    eventFct = eventf,
    solverFct = solverf,
    type = FC.fmi2TypeCoSimulation,
)
addStateAndDerivative(fmu, "x")
addOutput(fmu, "y")

callbacks = FC.fmi2CallbackFunctions(C_NULL, C_NULL, C_NULL, C_NULL, C_NULL)
callbacks_ref = Ref(callbacks)
callbacks_ptr = Base.unsafe_convert(Ptr{FC.fmi2CallbackFunctions}, callbacks_ref)

instance_name = "inst"
guid = string(fmu.modelDescription.guid)
resource = ""

c = FC.fmi2Instantiate(
    fmu.cInstantiate,
    pointer(instance_name),
    FC.fmi2TypeCoSimulation,
    pointer(guid),
    pointer(resource),
    callbacks_ptr,
    FC.fmi2False,
    FC.fmi2False,
)

@test FC.fmi2DoStep(fmu.cDoStep, c, 0.0, 0.25, FC.fmi2True) == FC.fmi2StatusOK

component = FMIExport.dereferenceInstance(c)
@test component.t == 0.25
@test component.values[fmu.modelDescription.stateValueReferences[1]] == 1.5

createFMU2Simple(
    initializationFct = init,
    evaluationFct = evalf,
    outputFct = outf,
    eventFct = eventf,
)
@test FMIExport.FMU_FCT_SOLVER() === nothing
