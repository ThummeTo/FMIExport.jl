#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

# export FMU script, currently only available on Windows
module ManipulationExample
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
    compare_fmpy_results_to_reference_states(
        fmpy_simulation_results,
        ManipulationExample.solution;
        atol = 0.2,
        rtol = 0.05,
    )
end
