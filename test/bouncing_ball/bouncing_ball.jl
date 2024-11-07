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
lockfile=joinpath(pwd(), "bouncing_ball", "lockfile.txt")
logfile=joinpath(pwd(), "bouncing_ball", "FMPy-log.txt")
t_start = "0.0"
t_stop = "5.0"
juliatestflag = "JULIA_@test:"
#fmu_save_path = joinpath(pwd(), "BouncingBall.fmu")
# as commandline interface for task sheduling in windows does only allow 261 characters for \TR option, we need an external config file
config_file = joinpath(pwd(), "bouncing_ball", "fmpy-bouncing_ball.config")
open(config_file, "w+") do io
    #line 1: lockfile
    write(io, lockfile)
    write(io, "\n")
    #line 2: logfile
    write(io, logfile)
    write(io, "\n")
    #line 3: fmu_save_path
    write(io, fmu_save_path)
    write(io, "\n")
    #line 4: juliatestflag
    write(io, juliatestflag)
    write(io, "\n")
    #line 5: t_start
    write(io, t_start)
    write(io, "\n")
    #line 5: t_stop
    write(io, t_stop)
    write(io, "\n")
end

script_file = joinpath(pwd(), "bouncing_ball", "fmpy-bouncing_ball.py")
if isfile(lockfile)
    rm(lockfile)
end
if isfile(logfile)
    rm(logfile)
end

`python -m pip install FMPy`

using Dates
tasktime = now() + Second(120)
time = Dates.format(tasktime, "HH:MM")
println("FMPY-DEBUG-Flag")
println(readchomp(`SCHTASKS /CREATE /SC ONCE /TN "ExternalFMIExportTesting\\BouncingBall-FMPy" /TR "python $script_file $config_file" /ST $time`))
sleep(150)
rm(config_file)
time_wait_max = datetime2unix(now()) + 600.0
if isfile(lockfile) || isfile(logfile)
    while isfile(lockfile) && datetime2unix(now()) < time_wait_max
        sleep(10)
    end
    println("wating for FMPy-Task ended; FMPy-Task done: " * string(!isfile(lockfile)))
    println(readchomp(`SCHTASKS /DELETE /TN ExternalFMIExportTesting\\BouncingBall-FMPy /f`))
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
    println(readchomp(`SCHTASKS /DELETE /TN ExternalFMIExportTesting\\BouncingBall-FMPy /f`))    
    @test false
end



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