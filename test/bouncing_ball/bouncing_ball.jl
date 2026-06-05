#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

fmu_save_path = nothing

# export FMU script, currently only available on Windows and Linux
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
    test_fmu_file(fmu_save_path, 300)
else
    # if not on windows or linux, use BouncingBall from FMIZoo
    using FMIZoo
    fmu_save_path = FMIZoo.get_model_filename("BouncingBall1D", "Dymola", "2023x")

    test_fmu_file(fmu_save_path, 300; size_unit=:KiB)
end

t_start = 0.0
t_stop = 3.0

function check_bouncing_ball_reference(fmpy_simulation_results, t_start, t_stop)
    default_fmpy_result_check(fmpy_simulation_results, t_start, t_stop)

    ts = collect(result_set[1] for result_set in fmpy_simulation_results)
    ss = collect(result_set[2] for result_set in fmpy_simulation_results)
    vs = collect(result_set[3] for result_set in fmpy_simulation_results)

    atol = 1e-2

    @test isapprox(ts[1], t_start; atol=atol)
    @test isapprox(ss[1], 1.0; atol=atol)
    @test isapprox(vs[1], 0.0; atol=atol)

    # Reference results from Dymola 2024X (CVODE)
    @test isapprox(ss[101], 0.658728; atol=atol)
    @test isapprox(vs[101], -1.82623; atol=atol)

    @test isapprox(ss[201], 0.371237; atol=atol)
    @test isapprox(vs[201], 2.01337; atol=atol)

    @test isapprox(ts[301], t_stop; atol=atol)
    @test isapprox(ss[301], 0.287215; atol=atol)
    @test isapprox(vs[301], -1.97912; atol=atol)
end

@testset "Model Exchange" begin
    run_fmpy_test(
        "bouncing_ball",
        "fmpy-bouncing_ball.py",
        "fmpy-bouncing_ball_ME.config",
        fmu_save_path;
        t_start=t_start,
        t_stop=t_stop,
        cleanup_fmu=false,
        config_lines=["ModelExchange"],
    ) do fmpy_simulation_results, t_start, t_stop
        check_bouncing_ball_reference(fmpy_simulation_results, t_start, t_stop)
    end
end

@testset "Co-Simulation" begin
    run_fmpy_test(
        "bouncing_ball",
        "fmpy-bouncing_ball.py",
        "fmpy-bouncing_ball_CS.config",
        fmu_save_path;
        t_start=t_start,
        t_stop=t_stop,
        cleanup_fmu=Sys.iswindows() || Sys.islinux(),
        config_lines=["CoSimulation", "0.001"],
    ) do fmpy_simulation_results, t_start, t_stop
        check_bouncing_ball_reference(fmpy_simulation_results, t_start, t_stop)
    end
end
