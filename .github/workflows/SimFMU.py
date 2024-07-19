#!/usr/bin/env python3

import fmpy
import os

FMU_PATH = ""
START = 0.0
STOP = 0.0

try:
    FMU_PATH = os.environ["FMU_PATH"]
    START = os.environ["START"]
    STOP = os.environ["STOP"]
except KeyError:
    print("Can't read inputs!")
    sys.exit(1)

#fmu_save_path = "C:/Users/thummeto/Documents/FMIZoo.jl/models/bin/Dymola/2023x/2.0/BouncingBallGravitySwitch1D.fmu"
#t_start = 0.0
#t_stop = 5.0

solution = fmpy.simulate_fmu(filename=FMU_PATH,
    validate=False,
    start_time=START,
    stop_time=STOP, record_events=True, solver="CVode")

print(solution[1])
sys.exit(0)