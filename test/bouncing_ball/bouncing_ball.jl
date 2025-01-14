#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

# export FMU script, currently only available on Windows
if Sys.iswindows()
    # TODO: reenable as soon as exporting FMUs is possible again
    #=
    include(
        joinpath(
            @__DIR__,
            "..",
            "..",
            "examples",
            "FMI2",
            "BouncingBall",
            "src",
            "BouncingBall.jl",
        ),
    )
    # check if FMU exists now
    @test isfile(fmu_save_path)
    fsize = filesize(fmu_save_path) / 1024 / 1024
    @test fsize > 300
    =#
    println(
        "::warning title=Test-Warning::exporting is not tested, as it is currently broken \r\n",
    )

    # TODO: as Exported FMUs are currently not able to be simulated with FMPy, use BouncingBall from FMIZoo instead to test Pipeline
    println(
        "::warning title=Test-Warning::using FMIZoo BouncingBallFMU instead of exported FMU. \r\n",
    )
    using FMIZoo
    fmu_save_path = FMIZoo.get_model_filename("BouncingBall1D", "Dymola", "2023x")
else
    # if not on windows, use BouncingBall from FMIZoo
    using FMIZoo
    fmu_save_path = FMIZoo.get_model_filename("BouncingBall1D", "Dymola", "2023x")

    # check if FMU exists
    @test isfile(fmu_save_path)
    fsize = filesize(fmu_save_path) / 1024 # / 1024 # check for 300KB instead of 300 MB as FMIZoo FMU is smaller
    @test fsize > 300
end

# mutex implementation: indicates running state of fmpy script. File must only be created and cleared afterwards by fmpy script
lockfile = joinpath(pwd(), "bouncing_ball", "lockfile.txt")
# fmpy script puts its logs here
logfile = joinpath(pwd(), "bouncing_ball", "FMPy-log.txt")
# output for scheduled command starting the fmpy script. meight be useful for debugging if logfile does not contain any helpful information on error
outlog = joinpath(pwd(), "bouncing_ball", "outlog.txt")
# fmu-experiment setup
t_start = 0.0
t_stop = 5.0

# as commandline interface for task sheduling in windows does only allow 261 characters for \TR option, we need a config file instead of commandline options
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
    #line 4: t_start
    write(io, string(t_start))
    write(io, "\n")
    #line 5: t_stop
    write(io, string(t_stop))
    write(io, "\n")
end
script_file = joinpath(pwd(), "bouncing_ball", "fmpy-bouncing_ball.py")

# should not exist but cleanup anyway
if isfile(lockfile)
    rm(lockfile)
end
if isfile(logfile)
    rm(logfile)
end

# install fmpy
println(readchomp(`python -m pip install FMPy`))

using Dates
# task can only be sheduled at full minutes, schedule with at least one full minute until start to avoid cornercases. 120s achives this optimally (seconds get truncated in minute-based-scheduling)
tasktime = now() + Second(120)
# cleanup github-actions logs
flush(stdout)
flush(stderr)

# the fmpy task that we want to schedule (its stdout and stderr get redirected for debugging, remains empty/non existent if no error occurs)
task_string = "python $script_file $config_file > $outlog 2>&1"

if Sys.iswindows()
    # in windows only 261 chars are allowed as command with args
    @test length(task_string) < 261
    time = Dates.format(tasktime, "HH:MM")
    println(
        readchomp(
            `SCHTASKS /CREATE /SC ONCE /TN "ExternalFMIExportTesting\\BouncingBall-FMPy" /TR "$task_string" /ST $time`,
        ),
    )
elseif Sys.islinux()
    time = Dates.format(tasktime, "M")
    open("crontab_fmiexport_fmpy_bouncingball", "w+") do io
        # hourly as there were issues when scheduling at fixed hour (not starting, possibly due to timzone issues or am/pm; did not investigate further)
        write(io, "$time * * * * $task_string")
        write(io, "\n")
    end
    println(readchomp(`crontab crontab_fmiexport_fmpy_bouncingball`))
end

# print schedule status for debugging
if Sys.iswindows()
    println(
        readchomp(
            `SCHTASKS /query /tn "ExternalFMIExportTesting\\BouncingBall-FMPy" /v /fo list`,
        ),
    )
elseif Sys.islinux()
    println(readchomp(`crontab -l`))
end

# wait until task has started for shure
sleep(150)

# cleanup
rm(config_file)

# we will wait a maximum time for fmpy. usually it should be done within seconds... (keep in mind maximum runtime on github runner)
time_wait_max = datetime2unix(now()) + 900.0

# fmpy still running or generated output in its logfile
if isfile(lockfile) || isfile(logfile)
    if isfile(lockfile)
        println(
            "FMPy-Task still running, will wait for termination or a maximum time of " *
            string(round((time_wait_max - datetime2unix(now())) / 60.0, digits = 2)) *
            " minutes from now.",
        )
    end
    while isfile(lockfile) && datetime2unix(now()) < time_wait_max
        sleep(10)
    end

    # print schedule status for debugging
    if Sys.iswindows()
        println(
            readchomp(
                `SCHTASKS /query /tn "ExternalFMIExportTesting\\BouncingBall-FMPy" /v /fo list`,
            ),
        )
    elseif Sys.islinux()
        println(readchomp(`crontab -l`))
    end

    println("wating for FMPy-Task ended; FMPy-Task done: " * string(!isfile(lockfile)))

    # sould not be existing/be empty; if there was no error, fmpy script redirected all its output to its own logfile (see FMPy_log below)
    if isfile(outlog)
        println("CMD output of FMPy-Task: ")
        for line in readlines(outlog)
            println(line)
        end
        println("------------------END_of_CMD_output--------------------")
    end

    global fmpy_simulation_results = nothing
    global parsing_done = false

    # FMPy_log
    if !isfile(logfile)
        println("No log of FMPy-Task found")
        @test false # error: no log by fmpy created
    else
        println("Log of FMPy-Task: ")
        for line in readlines(logfile)
            println(line)
            # if there is a "exception_occured_in_python_script" marker, fail test
            if contains(line, "exception_occured_in_python_script")
                @test false
            end

            global fmpy_simulation_results
            global parsing_done
            # if we are within the section of simulation results, parse them:
            if parsing_done # endmarker has been found already

            elseif !isnothing(fmpy_simulation_results) &&
                   contains(line, "---end_of_fmpy-simulation_results---") # endmarker has been found just now
                parsing_done = true
            elseif !isnothing(fmpy_simulation_results) && !parsing_done # we are currently in parsing mode
                push!(fmpy_simulation_results, parse.(Float64, split(line, ";")))
            elseif contains(line, "---begin_of_fmpy-simulation_results---") # found begin marker
                fmpy_simulation_results = []
            end
        end
        println("------------------END_of_FMPy_log--------------------")

        ts = collect(result_set[1] for result_set in fmpy_simulation_results)
        ss = collect(result_set[2] for result_set in fmpy_simulation_results)
        vs = collect(result_set[3] for result_set in fmpy_simulation_results)

        @test length(fmpy_simulation_results) == 1001

        @test isapprox(ts[1], t_start; atol = 1e-6)
        @test isapprox(ss[1], 1.0; atol = 1e-6)
        @test isapprox(vs[1], 0.0; atol = 1e-6)

        @test isapprox(ts[end], t_stop; atol = 1e-6)
        @test isapprox(ss[end], 0.23272552; atol = 1e-6)
        @test isapprox(vs[end], -0.17606235; atol = 1e-6)
    end
else
    println(
        "Error in FMPy-testsetup: Windows task scheduler or cron did not start FMPy successfully or FMPy terminated prematurely before generating lockfile or logfile",
    )
    @test false
end

# cleanup scheduling
if Sys.iswindows()
    println(
        readchomp(`SCHTASKS /DELETE /TN ExternalFMIExportTesting\\BouncingBall-FMPy /f`),
    )
elseif Sys.islinux()
    println(readchomp(`crontab -r`))
end

rm(fmu_save_path)
