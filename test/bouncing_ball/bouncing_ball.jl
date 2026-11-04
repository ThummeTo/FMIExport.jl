#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

function check_bouncing_ball_reference(fmpy_simulation_results, t_start, t_stop)
    default_fmpy_result_check(fmpy_simulation_results, t_start, t_stop)

    ts = collect(result_set[1] for result_set in fmpy_simulation_results)
    ss = collect(result_set[2] for result_set in fmpy_simulation_results)
    vs = collect(result_set[3] for result_set in fmpy_simulation_results)

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

# exports the BouncingBall example of the given FMI version and simulates it with FMPy (ME and CS)
function test_bouncing_ball(fmi_version::Integer)
    fmu_save_path = export_example("BouncingBall", fmi_version)
    test_fmu_file(fmu_save_path, 300)

    t_start = 0.0
    t_stop = 3.0

    @testset "Model Exchange" begin
        run_fmpy_test(
            check_bouncing_ball_reference,
            "bouncing_ball",
            "fmpy-bouncing_ball.py",
            "fmpy-bouncing_ball_fmi$(fmi_version)_ME.config",
            fmu_save_path;
            t_start = t_start,
            t_stop = t_stop,
            cleanup_fmu = false,
            config_lines = ["ModelExchange"],
        )
    end

    @testset "Co-Simulation" begin
        run_fmpy_test(
            check_bouncing_ball_reference,
            "bouncing_ball",
            "fmpy-bouncing_ball.py",
            "fmpy-bouncing_ball_fmi$(fmi_version)_CS.config",
            fmu_save_path;
            t_start = t_start,
            t_stop = t_stop,
            cleanup_fmu = true,
            config_lines = ["CoSimulation", "0.001"],
        )
    end
end
