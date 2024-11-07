import sys, os, traceback

with open(sys.argv[1]) as f:
    lines = f.read().splitlines()

lockfile = lines[0]
logfile = lines[1]
fmufile = lines[2]
juliatestflag = lines[3]
t_start = float(lines[4])
t_stop = float(lines[5])

f = open(lockfile, "w+")
f.write("FMPy_running")
f.close()

with open(logfile, "w+") as sys.stdout:
    print("fmpy-bouncing_ball.py log:")
    print("redirecting output...")
    import fmpy 
    fmpy.dump(fmufile)
    solution_FMPy = fmpy.simulate_fmu(filename=fmufile, validate=False, start_time=t_start, stop_time=t_stop, record_events=True, solver="Euler") # fmi_call_logger=lambda s: print('[FMI] ' + s)
    #solution_FMPy = fmpy.simulate_fmu(filename=fmufile, validate=False, start_time=t_start, stop_time=t_stop, record_events=True, solver="CVode") # fmi_call_logger=lambda s: print('[FMI] ' + s)
    try:
        print(juliatestflag+"(length_solution_FMPy="+str(len(solution_FMPy))+") == 1001")
        # ts = collect(solution_FMPy[i][1] for i in 1:len(solution_FMPy))
        # ss = collect(solution_FMPy[i][2] for i in 1:len(solution_FMPy))
        # vs = collect(solution_FMPy[i][3] for i in 1:len(solution_FMPy))
        print(juliatestflag+"isapprox((t_stop="+str(solution_FMPy[-1][0])+"), 5.0; atol=1e-6) # @test isapprox(ts[end], t_stop; atol=1e-6)")
        print(juliatestflag+"isapprox((s_end="+str(solution_FMPy[-1][1])+"), 0.23272552; atol=1e-6) # @test isapprox(ss[end], 0.23272552; atol=1e-6)")
        # print(juliatestflag+"isapprox((v_ens="+str(solution_FMPy[-1][2])+"), -0.17606235; atol=1e-6) # @test isapprox(vs[end], -0.17606235; atol=1e-6)")
    except Exception:
        print(traceback.format_exc())  
        print(juliatestflag+"false # exception occured in python script")
    print("fmpy-bouncing_ball.py done")
        
    
f = open(lockfile, "w")
f.write("FMPy_done")
f.close()
os.remove(lockfile)