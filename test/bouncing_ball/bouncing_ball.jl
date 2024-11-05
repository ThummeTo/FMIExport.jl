#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

# export FMU script
include(joinpath(@__DIR__, "..", "..", "examples", "FMI2", "BouncingBall", "src", "BouncingBall.jl"))

# demo!
#using FMIZoo, Test, Plots
#fmu_save_path = FMIZoo.get_model_filename("BouncingBall1D", "Dymola", "2022x")
#fmu_save_path = "C:/Users/thummeto/Documents/BouncingBall.fmu" # "C:/Users/thummeto/Documents/FMIZoo.jl/models/bin/Dymola/2023x/2.0/BouncingBallGravitySwitch1D.fmu"

# check if FMU exists now
@test isfile(fmu_save_path)
fsize = filesize(fmu_save_path)/1024/1024
@test fsize > 300

# Simulate FMU in Python / FMPy
lockfile=joinpath(pwd(), "test", "bouncing_ball", "lockfile.txt")
logfile=joinpath(pwd(), "test", "bouncing_ball", "FMPy-log.txt")

t_start = "0.0"
t_stop = "5.0"
juliatestflag = "JULIA_@test:"
fmu_save_path = joinpath(pwd(), "BouncingBall.fmu")
script_file = joinpath(pwd(), "test", "bouncing_ball", "fmpy-bouncing_ball.py")
rm(lockfile)
rm(logfile)

`python -m pip install FMPy`

using Dates
tasktime = now() + Second(120)
time = Dates.format(tasktime, "HH:MM")
println(readchomp(`SCHTASKS /CREATE /SC ONCE /TN "ExternalFMIExportTesting\\BouncingBall-FMPy" /TR "python $script_file --t_start=$t_start --t_stop=$t_stop --fmufile=$fmu_save_path --logfile=$logfile --lockfile=$lockfile --juliatestflag=$juliatestflag" /ST $time`))
sleep(150)
time_wait_max = datetime2unix(now()) + 600.0
if isfile(lockfile) || isfile(logfile)
    while isfile(lockfile) && datetime2unix(now()) < time_wait_max
        sleep(10)
    end
    println("wating for FMPy-Task ended; FMPy-Task done: " * String(!isfile(lockfile)))
    if !isfile(logfile)
        println("No log of FMPy-Task found")
        @test false # error: no log by fmpy created
    else
        println("Log of FMPy-Task: ")
        for line in readlines(logfile)
            println(line)
            if contains(line, juliatestflag)
                eval(Meta.parse("@test " * split(line, juliatestflag)[2]))
            end
        end
        println("------------------END_of_FMPy_log--------------------")
    end
else
    println("Error in FMPy-testsetup: Windows task scheduler did not start FMPy successfully or FMPy terminated prematurely before generating lock or logfiles")
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