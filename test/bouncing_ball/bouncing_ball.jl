#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

fmu_save_path = nothing

# export FMU script, currently only available on Windows
if Sys.iswindows() || Sys.islinux()
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
else
    # if not on windows or linux, use BouncingBall from FMIZoo
    using FMIZoo
    fmu_save_path = FMIZoo.get_model_filename("BouncingBall1D", "Dymola", "2023x")

    # check if FMU exists
    @test isfile(fmu_save_path)
    fsize = filesize(fmu_save_path) / 1024 # / 1024 # check for 300KB instead of 300 MB as FMIZoo FMU is smaller
    @test fsize > 300
end

# running FMPy only makes sense if we have an fmu file to check
if !isfile(fmu_save_path)
    throw("no fmu found, probably exporting failed")
end

# mutex implementation: indicates running state of fmpy script. File must only be created and cleared afterwards by fmpy script
lockfile = joinpath(pwd(), "bouncing_ball", "lockfile.txt")
# fmpy script puts its logs here
logfile = joinpath(pwd(), "bouncing_ball", "FMPy-log.txt")
# output for scheduled command starting the fmpy script. meight be useful for debugging if logfile does not contain any helpful information on error
outlog = joinpath(pwd(), "bouncing_ball", "outlog.txt")
# fmu-experiment setup
t_start = 0.0
t_stop = 3.0

# as commandline interface for task scheduling in windows does only allow 261 characters for \TR option, we need a config file instead of commandline options
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

# cleanup github-actions logs
flush(stdout)
flush(stderr)

if isfile(outlog)
    rm(outlog)
end

fmpy_cmd = pipeline(`python $script_file $config_file`; stdout = outlog, stderr = outlog)
fmpy_success = success(fmpy_cmd)
if !fmpy_success
    println("FMPy process exited with an error; see captured output below.")
end

# cleanup
rm(config_file)

# we will wait a maximum time for fmpy. usually it should be done within seconds... (keep in mind maximum runtime on github runner)
time_wait_max = time() + 60.0 * 5

# fmpy still running or generated output in its logfile
if isfile(lockfile) || isfile(logfile)
    if isfile(lockfile)
        println(
            "FMPy-Task still running, will wait for termination or a maximum time of " *
            string(round((time_wait_max - time()) / 60.0, digits = 2)) *
            " minutes from now.",
        )
    end
    while isfile(lockfile) && time() < time_wait_max
        sleep(10)
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
            # if we are within the section of simulation results, parse them:
            if !isnothing(fmpy_simulation_results) &&
               contains(line, "---end_of_fmpy-simulation_results---") # endmarker has been found just now
                break
            elseif !isnothing(fmpy_simulation_results) # we are currently in parsing mode
                push!(fmpy_simulation_results, parse.(Float64, split(line, ";")))
            elseif contains(line, "---begin_of_fmpy-simulation_results---") # found begin marker
                fmpy_simulation_results = []
            end
        end
        println("------------------END_of_FMPy_log--------------------")

        if isnothing(fmpy_simulation_results)
            @error "`fmpy_simulation_results` is nothing, no results in output file."
            @test false
        else

            ts = collect(result_set[1] for result_set in fmpy_simulation_results)
            ss = collect(result_set[2] for result_set in fmpy_simulation_results)
            vs = collect(result_set[3] for result_set in fmpy_simulation_results)

            # sometimes, FMPy does one step more than expected ...
            tar = round(Int, (t_stop - t_start) * 100 + 1)
            @test abs(length(fmpy_simulation_results) - tar) <= 1

            atol = 1e-2

            @test isapprox(ts[1], t_start; atol = atol)
            @test isapprox(ss[1], 1.0; atol = atol)
            @test isapprox(vs[1], 0.0; atol = atol)

            # Reference results from Dymola 2024X (CVODE)
            @test isapprox(ss[101], 0.658728; atol = atol)
            @test isapprox(vs[101], -1.82623; atol = atol)

            @test isapprox(ss[201], 0.371237; atol = atol)
            @test isapprox(vs[201], 2.01337; atol = atol)

            @test isapprox(ts[301], t_stop; atol = atol)
            @test isapprox(ss[301], 0.287215; atol = atol)
            @test isapprox(vs[301], -1.97912; atol = atol)
        end
    end
else
    println(
        "Error in FMPy-testsetup: Windows task scheduler or cron did not start FMPy successfully or FMPy terminated prematurely before generating lockfile or logfile",
    )
    @test false
end

if isfile(fmu_save_path)
    rm(fmu_save_path)
end
