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

fmu = createFMU3Simple(
    initializationFct = init,
    evaluationFct = evalf,
    outputFct = outf,
    eventFct = eventf,
    solverFct = solverf,
    type = FC.fmi3TypeCoSimulation,
)
addCoSimulation(fmu)
addStateAndDerivative(fmu, "x")
addOutput(fmu, "y")

instance_name = "inst"
token = fmu.modelDescription.instantiationToken
resource = ""

c = FC.fmi3InstantiateCoSimulation(
    fmu.cInstantiateCoSimulation,
    pointer(instance_name),
    pointer(token),
    pointer(resource),
    FC.fmi3False,
    FC.fmi3False,
    FC.fmi3False,
    FC.fmi3False,
    Ptr{FC.fmi3ValueReference}(C_NULL),
    Csize_t(0),
    C_NULL,
    C_NULL,
    C_NULL,
)

# values set before initialization are kept (not overwritten by the initialization function)
vr = [fmu.modelDescription.stateValueReferences[1]]
@test FC.fmi3SetFloat64(fmu.cSetFloat64, c, vr, Csize_t(1), [3.0], Csize_t(1)) ==
      FC.fmi3StatusOK

@test FC.fmi3EnterInitializationMode(
    fmu.cEnterInitializationMode,
    c,
    FC.fmi3False,
    0.0,
    0.0,
    FC.fmi3False,
    0.0,
) == FC.fmi3StatusOK
@test FC.fmi3ExitInitializationMode(fmu.cExitInitializationMode, c) == FC.fmi3StatusOK

eventHandlingNeeded = Ref(FC.fmi3True)
terminateSimulation = Ref(FC.fmi3True)
earlyReturn = Ref(FC.fmi3True)
lastSuccessfulTime = Ref(0.0)
@test FC.fmi3DoStep!(
    fmu.cDoStep,
    c,
    0.0,
    0.25,
    FC.fmi3True,
    eventHandlingNeeded,
    terminateSimulation,
    earlyReturn,
    lastSuccessfulTime,
) == FC.fmi3StatusOK
@test lastSuccessfulTime[] == 0.25
@test terminateSimulation[] == FC.fmi3False

instance = FMIExport.dereferenceInstance(c)
@test instance.t == 0.25
@test instance.values[fmu.modelDescription.stateValueReferences[1]] == 3.5

# the `CFunction`s behind the function pointers are kept as long as the FMU exists
GC.gc(true)
stored = [c_fun.ptr for c_fun in FMIExport.FMU_CFUNCTIONS[fmu]]
for field in
    (:cInstantiateCoSimulation, :cFreeInstance, :cDoStep, :cGetFloat64, :cGetFloat32)
    @test getfield(fmu, field) in stored
end

# unsupported functions return `fmi3Error`
@test FC.fmi3GetFloat32!(
    fmu.cGetFloat32,
    c,
    FC.fmi3ValueReference[1],
    Csize_t(1),
    zeros(FC.fmi3Float32, 1),
    Csize_t(1),
) == FC.fmi3StatusError

FC.fmi3FreeInstance(fmu.cFreeInstance, c)
@test isempty(fmu.instances)
