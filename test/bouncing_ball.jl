#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

# export FMU script
include(joinpath(@__DIR__, "..", "examples", "FMI2", "BouncingBall", "src", "BouncingBall.jl"))

# demo!
#using FMIZoo, Test, Plots
#fmu_save_path = FMIZoo.get_model_filename("BouncingBall1D", "Dymola", "2022x")
#fmu_save_path = "C:/Users/thummeto/Documents/BouncingBall.fmu" # "C:/Users/thummeto/Documents/FMIZoo.jl/models/bin/Dymola/2023x/2.0/BouncingBallGravitySwitch1D.fmu"

# check if FMU exists now
@test isfile(fmu_save_path)
fsize = filesize(fmu_save_path)/1024/1024
@test fsize > 300

# Simulate FMU in Python / FMPy
lockfile=replace(joinpath(pwd(),"lockfile.txt"), "\\" => "\\\\")
logfile=replace(joinpath(pwd(),"FMPy-log.txt"), "\\" => "\\\\")
fmu_save_path_escaped=replace(fmu_save_path, "\\" => "\\\\")
FMPyScript = """
f = open("$lockfile", "w+")
f.write("FMPy_running")
f.close()

import sys
import traceback
with open("$logfile", "w+") as sys.stdout:
    print("redirecting output...")
    import fmpy 
    fmpy.dump("$fmu_save_path_escaped")
    solution_FMPy = fmpy.simulate_fmu(filename="$fmu_save_path_escaped", validate=False, start_time=0.0, stop_time=5.0, record_events=True, solver="Euler") # fmi_call_logger=lambda s: print('[FMI] ' + s)
    try:
        print("JULIA_@test:(length_solution_FMPy="+str(len(solution_FMPy))+") == 1001 # length(solution_FMPy) == 1001")
        # ts = collect(solution_FMPy[i][1] for i in 1:len(solution_FMPy))
        # ss = collect(solution_FMPy[i][2] for i in 1:len(solution_FMPy))
        # vs = collect(solution_FMPy[i][3] for i in 1:len(solution_FMPy))
        print("JULIA_@test:isapprox((t_stop="+str(solution_FMPy[-1][0])+"), 5.0; atol=1e-6) # @test isapprox(ts[end], t_stop; atol=1e-6)")
        print("JULIA_@test:isapprox((s_end="+str(solution_FMPy[-1][1])+"), 0.23272552; atol=1e-6) # @test isapprox(ss[end], 0.23272552; atol=1e-6)")
        # print("JULIA_@test:isapprox((v_ens="+str(solution_FMPy[-1][2])+"), -0.17606235; atol=1e-6) # @test isapprox(vs[end], -0.17606235; atol=1e-6)")
    except Exception:
        print(traceback.format_exc())  
        print("JULIA_@test:false")
        
    
f = open("$lockfile", "w+")
f.write("FMPy_done")
f.close()
"""
script_file = joinpath(pwd(), "BouncingBallFMPy.py")
write(script_file, FMPyScript)
`python -m pip install FMPy`
using Dates
tasktime = now() + Second(120)
day = Dates.format(tasktime, "e")
time = Dates.format(tasktime, "HH:MM")
println(readchomp(`SCHTASKS /CREATE /SC WEEKLY /D $day /TN "ExternalFMIExportTesting\\BouncingBall-FMPy" /TR "python $script_file" /ST $time`))
sleep(150)
time_wait_max = datetime2unix(now()) + 600.0
if isfile(lockfile)
    while "FMPy_running" in read(lockfile) && datetime2unix(now()) < time_wait_max
        sleep(10)
    end
    println("wating for FMPy-Task ended; status of FMPy-Task: " * String(read(lockfile)) * "; Log of FMPy-Task: ")
    for line in readlines(logfile)
        println(line)
        if contains(line, "JULIA_@test:")
            eval(Meta.parse("@test " * split(line, "JULIA_@test:")[2]))
        end
    end
    println("------------------END_of_FMPy_log--------------------")
else
    println("Error in FMPy testsetup: Windows task scheduler did not start FMPy successfully or FMPy terminated prematurely")
    @test false
end
println(readchomp(`SCHTASKS /DELETE /TN ExternalFMIExportTesting\\BouncingBall-FMPy /f`))


# @test length(solution_FMPy) == 1001

# @test isapprox(ts[1], t_start; atol=1e-6)
# @test isapprox(ss[1], 1.0; atol=1e-6)
# @test isapprox(vs[1], 0.0; atol=1e-6)

# @test isapprox(ts[end], t_stop; atol=1e-6)
# @test isapprox(ss[end], 0.23272552; atol=1e-6)
# @test isapprox(vs[end], -0.17606235; atol=1e-6)

# plot(ts, ss)
# plot(ts, vs)

# ToDo: enable the following line
rm(fmu_save_path)