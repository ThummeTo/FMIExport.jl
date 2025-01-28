#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

# export FMU script
include(joinpath(@__DIR__, "..", "examples", "FMI2", "Manipulation", "src", "Manipulation.jl"))

# check if FMU exists now
@test isfile(fmu_save_path)

# Simulate FMU in Python / FMPy
# @info "Installing `fmpy`..."
# using Conda
# Conda.add("fmpy"; channel="conda-forge")

# @info "Simulating with `fmpy`..."
# using PyCall
# fmpy = pyimport("fmpy")
# fmpy.dump(fmu_save_path)

# ToDo: Unfortunately, this errors ... (but it runs in python shell)
# solution_FMPy = fmpy.simulate_fmu(filename=fmu_save_path,
#     validate=false,
#     start_time=0.0,
#     stop_time=5.0,
#     solver="CVode",
#     step_size=1e-2,
#     output_interval=2e-2,
#     record_events=true) # , fmi_call_logger=lambda s: print('[FMI] ' + s) 

# Simulate FMU in Julia / FMI.jl
# using FMI
# fmu.executionConfig.loggingOn = true
# solution_FMI_jl = fmiSimulateME(fmu, (0.0, 5.0); dtmax=0.1)

# ToDo check results
# @test solution_FMI_jl.states.t[end] == 5.0
# @test solution_FMI_jl.states.u[end] == [0.0, 0.0]

rm(fmu_save_path)
