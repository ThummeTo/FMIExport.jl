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
FMPyScript = """
f = open("$lockfile", "w+")
f.write("FMPy_running")
f.close()

import sys
with open("$logfile", "w+") as sys.stdout:
    print("redirecting output...")
    import subprocess
    import sys
    subprocess.check_call([sys.executable, "-m", "pip", "install", "FMPy"])
    import FMPy
    FMPy.dump($fmu_save_path)

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
while "FMPy_running" in read(lockfile) && datetime2unix(now()) < time_wait_max
    sleep(10)
end
println("wating for FMPy-Task ended; status of FMPy-Task: " * String(read(lockfile)) * "; Log of FMPy-Task: ")
for line in readlines(logfile)
    println(line)
end
println("------------------END_of_FMPy_log--------------------")
println(readchomp(`SCHTASKS /DELETE /TN ExternalFMIExportTesting\\BouncingBall-FMPy /f`))


# @info "Installing `FMPy`..."
# using Conda
# Conda.add("FMPy"; channel="conda-forge")

# @info "Simulating with `FMPy`..."
# using PyCall
# @pyimport FMPy
# FMPy.dump(fmu_save_path)

# t_start = 0.0
# t_stop = 5.0

# solution_FMPy = FMPy.simulate_fmu(filename=fmu_save_path,
#     validate=false,
#     start_time=t_start,
#     stop_time=t_stop, record_events=true, solver="CVode") # fmi_call_logger=lambda s: print('[FMI] ' + s) , 

# ts = collect(solution_FMPy[i][1] for i in 1:length(solution_FMPy))
# ss = collect(solution_FMPy[i][2] for i in 1:length(solution_FMPy))
# vs = collect(solution_FMPy[i][3] for i in 1:length(solution_FMPy))

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