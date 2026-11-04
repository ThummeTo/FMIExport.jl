#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

# exports the Manipulation example of the given FMI version and simulates it with FMPy (ME),
# the FMU's only output is the position of the embedded SpringPendulum1D with noise (at most 1e-2)
function test_manipulation(fmi_version::Integer)
    fmu_save_path = export_example("Manipulation", fmi_version)
    test_fmu_file(fmu_save_path, 150)

    run_fmpy_test(
        "manipulation",
        "fmpy-manipulation.py",
        "fmpy-manipulation_fmi$(fmi_version).config",
        fmu_save_path;
        t_start = 0.0,
        t_stop = 5.0,
    ) do fmpy_simulation_results, t_start, t_stop
        default_fmpy_result_check(fmpy_simulation_results, t_start, t_stop)
        compare_fmpy_results_to_expected_rows(
            fmpy_simulation_results,
            [
                i => [t, spring_pendulum_solution(t, 1.0)[1]] for
                (i, t) in zip(1:100:501, 0.0:1.0:5.0)
            ];
            atol = 2e-2,
        )

        # the output is really manipulated
        noise = [
            row[2] - spring_pendulum_solution(row[1], 1.0)[1] for
            row in fmpy_simulation_results
        ]
        @test maximum(abs.(noise)) > 1e-3
    end
end
