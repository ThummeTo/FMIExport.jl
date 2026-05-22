#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

# export FMU script
module NeuralFMUExample
include(
    joinpath(@__DIR__, "..", "..", "examples", "FMI2", "NeuralFMU", "src", "NeuralFMU.jl"),
)
end
fmu_save_path = NeuralFMUExample.fmu_save_path

test_fmu_file(fmu_save_path, 600)

run_fmpy_test(
    "neuralFMU",
    "fmpy-neuralFMU.py",
    "fmpy-neuralFMU.config",
    fmu_save_path;
    t_start = 0.0,
    t_stop = 5.0,
) do fmpy_simulation_results, t_start, t_stop
    default_fmpy_result_check(fmpy_simulation_results, t_start, t_stop)
    compare_fmpy_results_to_expected_rows(
        fmpy_simulation_results,
        [
            1 => [0.0, 0.5, 0.0],
            101 => [1.0, 1.2850756740879399, 0.0],
            201 => [2.0, 1.1179054787989338, 0.0],
            301 => [3.0, 0.6037555652882566, 0.0],
            401 => [4.0, 1.3582997301862976, 0.0],
            501 => [5.0, 0.9380254299104219, 0.0],
        ];
        atol = 1e-2,
    )
end
