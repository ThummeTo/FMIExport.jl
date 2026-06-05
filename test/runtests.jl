#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

using FMIExport
using Test

function test_fmu_file(fmu_save_path, minimum_size; size_unit = :MiB)
    @test isfile(fmu_save_path)

    divisor = if size_unit == :MiB
        1024 * 1024
    elseif size_unit == :KiB
        1024
    else
        throw(ArgumentError("Unsupported size unit: $(size_unit)."))
    end

    @test filesize(fmu_save_path) / divisor > minimum_size

    if !isfile(fmu_save_path)
        throw("no fmu found, probably exporting failed")
    end
end

function default_fmpy_result_check(fmpy_simulation_results, t_start, t_stop)
    tar = round(Int, (t_stop - t_start) * 100 + 1)
    @test abs(length(fmpy_simulation_results) - tar) <= 1
end

function compare_fmpy_results_to_reference_solution(
    fmpy_simulation_results,
    reference_solution;
    fmpy_value_indices = nothing,
    reference_value_indices = nothing,
    atol = 1e-2,
    rtol = 1e-2,
)
    @test !isnothing(reference_solution.values)
    if isnothing(reference_solution.values)
        return
    end

    result_count = length(fmpy_simulation_results)
    reference_count = length(reference_solution.values.t)
    common_count = min(result_count, reference_count)
    @test abs(result_count - reference_count) <= 1

    fmpy_value_count = length(fmpy_simulation_results[1]) - 1
    reference_value_count = length(reference_solution.values.saveval[1])
    if isnothing(fmpy_value_indices)
        fmpy_value_indices = 1:fmpy_value_count
    end
    if isnothing(reference_value_indices)
        reference_value_indices =
            (reference_value_count-length(fmpy_value_indices)+1):reference_value_count
    end
    @test length(reference_value_indices) == length(fmpy_value_indices)

    fmpy_times = [row[1] for row in fmpy_simulation_results[1:common_count]]
    reference_times = reference_solution.values.t[1:common_count]
    max_time_error = maximum(abs.(fmpy_times .- reference_times))
    @test max_time_error <= 1e-8

    max_value_error = 0.0
    max_value_scale = 0.0
    for i = 1:common_count
        fmpy_values = fmpy_simulation_results[i][collect(fmpy_value_indices) .+ 1]
        reference_values =
            collect(reference_solution.values.saveval[i])[collect(reference_value_indices)]
        max_value_error =
            max(max_value_error, maximum(abs.(fmpy_values .- reference_values)))
        max_value_scale = max(max_value_scale, maximum(abs.(reference_values)))
    end

    @test max_value_error <= atol + rtol * max_value_scale
end

function compare_fmpy_results_to_reference_states(
    fmpy_simulation_results,
    reference_solution;
    fmpy_value_indices = nothing,
    state_indices = nothing,
    atol = 1e-2,
    rtol = 1e-2,
)
    @test !isnothing(reference_solution.states)
    if isnothing(reference_solution.states)
        return
    end

    result_count = length(fmpy_simulation_results)
    reference_count = length(reference_solution.states.t)
    common_count = min(result_count, reference_count)
    @test abs(result_count - reference_count) <= 1

    fmpy_value_count = length(fmpy_simulation_results[1]) - 1
    if isnothing(fmpy_value_indices)
        fmpy_value_indices = 1:fmpy_value_count
    end
    if isnothing(state_indices)
        state_indices = 1:length(fmpy_value_indices)
    end
    @test length(state_indices) == length(fmpy_value_indices)

    fmpy_times = [row[1] for row in fmpy_simulation_results[1:common_count]]
    reference_times = reference_solution.states.t[1:common_count]
    max_time_error = maximum(abs.(fmpy_times .- reference_times))
    @test max_time_error <= 1e-8

    max_value_error = 0.0
    max_value_scale = 0.0
    for i = 1:common_count
        fmpy_values = fmpy_simulation_results[i][collect(fmpy_value_indices) .+ 1]
        reference_values = reference_solution.states.u[i][collect(state_indices)]
        max_value_error =
            max(max_value_error, maximum(abs.(fmpy_values .- reference_values)))
        max_value_scale = max(max_value_scale, maximum(abs.(reference_values)))
    end

    @test max_value_error <= atol + rtol * max_value_scale
end

function compare_fmpy_results_to_expected_rows(
    fmpy_simulation_results,
    expected_rows;
    atol = 1e-2,
)
    for (index, expected_row) in expected_rows
        @test length(fmpy_simulation_results) >= index
        @test length(fmpy_simulation_results[index]) == length(expected_row)
        max_row_error = maximum(abs.(fmpy_simulation_results[index] .- expected_row))
        @test max_row_error <= atol
    end
end

function run_fmpy_test(
    test_dir::AbstractString,
    script_name::AbstractString,
    config_name::AbstractString,
    fmu_save_path::AbstractString;
    t_start,
    t_stop,
    cleanup_fmu = true,
    config_lines = String[],
    timeout_minutes = 5.0,
)
    run_fmpy_test(
        default_fmpy_result_check,
        test_dir,
        script_name,
        config_name,
        fmu_save_path;
        t_start = t_start,
        t_stop = t_stop,
        cleanup_fmu = cleanup_fmu,
        config_lines = config_lines,
        timeout_minutes = timeout_minutes,
    )
end

function run_fmpy_test(
    result_check::Function,
    test_dir::AbstractString,
    script_name::AbstractString,
    config_name::AbstractString,
    fmu_save_path::AbstractString;
    t_start,
    t_stop,
    cleanup_fmu = true,
    config_lines = String[],
    timeout_minutes = 5.0,
)
    test_path = joinpath(pwd(), test_dir)
    lockfile = joinpath(test_path, "lockfile.txt")
    logfile = joinpath(test_path, "FMPy-log.txt")
    outlog = joinpath(test_path, "outlog.txt")
    config_file = joinpath(test_path, config_name)
    script_file = joinpath(test_path, script_name)

    try
        open(config_file, "w+") do io
            println(io, lockfile)
            println(io, logfile)
            println(io, fmu_save_path)
            println(io, t_start)
            println(io, t_stop)
            for line in config_lines
                println(io, line)
            end
        end

        for file in (lockfile, logfile, outlog)
            if isfile(file)
                rm(file)
            end
        end

        println(readchomp(`python -m pip install FMPy`))
        flush(stdout)
        flush(stderr)

        fmpy_cmd =
            pipeline(`python $script_file $config_file`; stdout = outlog, stderr = outlog)
        fmpy_success = success(fmpy_cmd)
        if !fmpy_success
            println("FMPy process exited with an error; see captured output below.")
        end
    finally
        if isfile(config_file)
            rm(config_file)
        end
    end

    time_wait_max = time() + 60.0 * timeout_minutes

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

        println("Waiting for FMPy-Task ended; FMPy-Task done: " * string(!isfile(lockfile)))

        if isfile(outlog)
            println("CMD output of FMPy-Task: ")
            for line in readlines(outlog)
                println(line)
            end
            println("------------------END_of_CMD_output--------------------")
        end

        fmpy_simulation_results = nothing

        if !isfile(logfile)
            println("No log of FMPy-Task found")
            @test false
        else
            println("Log of FMPy-Task: ")
            for line in readlines(logfile)
                println(line)
                if contains(line, "exception_occured_in_python_script")
                    @test false
                end

                if !isnothing(fmpy_simulation_results) &&
                   contains(line, "---end_of_fmpy-simulation_results---")
                    break
                elseif !isnothing(fmpy_simulation_results)
                    push!(fmpy_simulation_results, parse.(Float64, split(line, ";")))
                elseif contains(line, "---begin_of_fmpy-simulation_results---")
                    fmpy_simulation_results = []
                end
            end
            println("------------------END_of_FMPy_log--------------------")

            if isnothing(fmpy_simulation_results)
                @error "`fmpy_simulation_results` is nothing, no results in output file."
                @test false
            else
                result_check(fmpy_simulation_results, t_start, t_stop)
            end
        end
    else
        println(
            "Error in FMPy-testsetup: FMPy did not start successfully or terminated prematurely before generating lockfile or logfile",
        )
        @test false
    end

    if cleanup_fmu && isfile(fmu_save_path)
        rm(fmu_save_path)
    end
end

@testset "FMIExport.jl" begin
    if Sys.iswindows() || Sys.islinux()
        @info "Automated testing is supported on Windows/Linux"

        @testset "Model Description" begin
            include("model_description.jl")
        end

        @testset "Co-Simulation" begin
            include("cosimulation.jl")
        end

        @testset "Bouncing Ball" begin
            include(joinpath("bouncing_ball", "bouncing_ball.jl"))
        end

        @testset "FMU Manipulation" begin
            include(joinpath("manipulation", "manipulation.jl"))
        end

        @testset "Neural FMU" begin
            include(joinpath("neuralFMU", "neuralFMU.jl"))
        end

    elseif Sys.isapple()
        @warn "Tests not supported on Mac."
    else
        @warn "Tests not supported on `unknown operation system`."
    end
end
