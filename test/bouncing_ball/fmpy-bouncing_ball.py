import argparse, sys, os, traceback

parser=argparse.ArgumentParser()

parser.add_argument("--t_start", help="start-time for FMU simulation")
parser.add_argument("--t_stop", help="stop-time for FMU simulation")
parser.add_argument("--fmufile", help="path to .fmu file")
parser.add_argument("--logfile", help="logfile for redirecting output")
parser.add_argument("--lockfile", help="lockfile for indicating status")
parser.add_argument("--juliatestflag", help="flag for printing to log that gets replaced by \"@test \" by julia afterwards")

args=parser.parse_args()

f = open(args.lockfile, "w+")
f.write("FMPy_running")
f.close()

with open(args.logfile, "w+") as sys.stdout:
    print("fmpy-bouncing_ball.py log:")
    print("redirecting output...")
    import fmpy 
    fmpy.dump(args.fmufile)
    solution_FMPy = fmpy.simulate_fmu(filename=args.fmufile, validate=False, start_time=args.t_start, stop_time=args.t_stop, record_events=True, solver="Euler") # fmi_call_logger=lambda s: print('[FMI] ' + s)
    #solution_FMPy = fmpy.simulate_fmu(filename=args.fmufile, validate=False, start_time=args.t_start, stop_time=args.t_stop, record_events=True, solver="CVode") # fmi_call_logger=lambda s: print('[FMI] ' + s)
    try:
        print(args.juliatestflag+"(length_solution_FMPy="+str(len(solution_FMPy))+") == 1001")
        # ts = collect(solution_FMPy[i][1] for i in 1:len(solution_FMPy))
        # ss = collect(solution_FMPy[i][2] for i in 1:len(solution_FMPy))
        # vs = collect(solution_FMPy[i][3] for i in 1:len(solution_FMPy))
        print(args.juliatestflag+"isapprox((t_stop="+str(solution_FMPy[-1][0])+"), 5.0; atol=1e-6) # @test isapprox(ts[end], t_stop; atol=1e-6)")
        print(args.juliatestflag+"isapprox((s_end="+str(solution_FMPy[-1][1])+"), 0.23272552; atol=1e-6) # @test isapprox(ss[end], 0.23272552; atol=1e-6)")
        # print(args.juliatestflag+"isapprox((v_ens="+str(solution_FMPy[-1][2])+"), -0.17606235; atol=1e-6) # @test isapprox(vs[end], -0.17606235; atol=1e-6)")
    except Exception:
        print(traceback.format_exc())  
        print(args.juliatestflag+"false # exception occured in python script")
        
    
f = open(args.lockfile, "w")
f.write("FMPy_done")
f.close()
os.remove(args.lockfile)