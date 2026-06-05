FC = FMIExport.FMICore

init() = (0.0, [1.0], [2.0], [], [], [])
evalf(t, xc, xcdot, xd, u, p, eventMode) = (xc, [2.0], xd, p)
outf(t, xc, xcdot, xd, u, p) = xc
eventf(t, xc, xcdot, xd, u, p) = Float64[]

fmu = fmi2CreateSimple(
    initializationFct = init,
    evaluationFct = evalf,
    outputFct = outf,
    eventFct = eventf,
    type = FC.fmi2TypeCoSimulation,
)
fmi2AddStateAndDerivative(fmu, "x")
fmi2AddOutput(fmu, "y")

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
