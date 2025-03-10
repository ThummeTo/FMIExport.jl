import fmpy
fmpy.dump(fmufile)
solution_FMPy = fmpy.simulate_fmu(
        filename="BouncingBall.fmu",
        output_interval=0.01,
        validate=False,
        start_time=0.0,
        stop_time=3.0,
        record_events=False,
        solver='CVode',
        )

