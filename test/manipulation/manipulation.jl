#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

# export FMU script, currently only available on Windows
module ManipulationExample
previous_skip_reference_simulation =
    get(ENV, "FMIEXPORT_SKIP_REFERENCE_SIMULATION", nothing)
ENV["FMIEXPORT_SKIP_REFERENCE_SIMULATION"] = "true"
try
    include(
        joinpath(
            @__DIR__,
            "..",
            "..",
            "examples",
            "FMI2",
            "Manipulation",
            "src",
            "Manipulation.jl",
        ),
    )
finally
    if isnothing(previous_skip_reference_simulation)
        delete!(ENV, "FMIEXPORT_SKIP_REFERENCE_SIMULATION")
    else
        ENV["FMIEXPORT_SKIP_REFERENCE_SIMULATION"] = previous_skip_reference_simulation
    end
end
end
fmu_save_path = ManipulationExample.fmu_save_path
test_fmu_file(fmu_save_path, 150)

run_fmpy_test(
    "manipulation",
    "fmpy-manipulation.py",
    "fmpy-manipulation.config",
    fmu_save_path;
    t_start = 0.0,
    t_stop = 5.0,
) do fmpy_simulation_results, t_start, t_stop
    default_fmpy_result_check(fmpy_simulation_results, t_start, t_stop)
    compare_fmpy_results_to_expected_rows(
        fmpy_simulation_results,
        [
            1 => [0.0, 0.5, 0.0],
            101 => [1.0, 1.4619, -0.0275],
            201 => [2.0, 0.5908, 0.0497],
            301 => [3.0, 1.3797, -0.0673],
            401 => [4.0, 0.6731, 0.0811],
            501 => [5.0, 1.3014, -0.0917],
        ];
        atol = 5e-2,
    )
end
