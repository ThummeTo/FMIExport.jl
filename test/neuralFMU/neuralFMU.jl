#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

# exports the NeuralFMU example of the given FMI version and simulates it with FMPy (ME),
# the ANN halves the acceleration of the embedded SpringPendulum1D
function test_neural_fmu(fmi_version::Integer)
    fmu_save_path = export_example("NeuralFMU", fmi_version)
    test_fmu_file(fmu_save_path, 600)

    run_fmpy_test(
        "neuralFMU",
        "fmpy-neuralFMU.py",
        "fmpy-neuralFMU_fmi$(fmi_version).config",
        fmu_save_path;
        t_start = 0.0,
        t_stop = 5.0,
        config_lines = ["mass.s,mass.v"],
    ) do fmpy_simulation_results, t_start, t_stop
        default_fmpy_result_check(fmpy_simulation_results, t_start, t_stop)
        compare_fmpy_results_to_expected_rows(
            fmpy_simulation_results,
            [
                i => [t, spring_pendulum_solution(t, 0.5)...] for
                (i, t) in zip(1:100:501, 0.0:1.0:5.0)
            ];
            atol = 1e-2,
        )
    end
end
