#!/usr/bin/python
# -*- coding: utf-8 -*-
import sys
import os
import traceback

with open(sys.argv[1]) as f:
    lines = f.read().splitlines()

lockfile = lines[0]
logfile = lines[1]
fmufile = lines[2]
t_start = float(lines[3])
t_stop = float(lines[4])

f = open(lockfile, 'w+')
f.write('FMPy_running')
f.close()

with open(logfile, 'w+') as sys.stdout:
    print('fmpy-bouncing_ball.py log:')
    print('redirecting output...')
    import fmpy
    print('imported fmpy')
    fmpy.dump(fmufile)
    solution_FMPy = fmpy.simulate_fmu(
        filename=fmufile,
        validate=False,
        start_time=t_start,
        stop_time=t_stop,
        record_events=True,
        solver='CVode',
        )
    try:
        print("---begin_of_fmpy-simulation_results---")
        for elem in solution_FMPy:
            print(';'.join(elem))
        print("---end_of_fmpy-simulation_results---")
    except Exception:
        print(traceback.format_exc())
        print('exception_occured_in_python_script')
    print('fmpy-bouncing_ball.py done')

f = open(lockfile, 'w')
f.write('FMPy_done')
f.close()
os.remove(lockfile)
