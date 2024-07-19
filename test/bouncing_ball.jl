#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

# export FMU script
include(joinpath(@__DIR__, "..", "examples", "FMI2", "BouncingBall", "src", "BouncingBall.jl"))

# demo!
using FMIZoo, Test, Plots
#fmu_save_path = FMIZoo.get_model_filename("BouncingBall1D", "Dymola", "2022x")
fmu_save_path = "C:/Users/thummeto/Documents/FMIZoo.jl/models/bin/Dymola/2023x/2.0/BouncingBallGravitySwitch1D.fmu"

# check if FMU exists now
@test isfile(fmu_save_path)

# Simulate FMU in Python / FMPy
@info "Installing `fmpy`..."
using Conda
Conda.add("fmpy"; channel="conda-forge")

# @info "Simulating with `fmpy`..."
using PyCall
@pyimport fmpy
fmpy.dump(fmu_save_path)

t_start = 0.0
t_stop = 5.0

solution_FMPy = fmpy.simulate_fmu(filename=fmu_save_path,
    validate=false,
    start_time=t_start,
    stop_time=t_stop, record_events=true, solver="CVode") # fmi_call_logger=lambda s: print('[FMI] ' + s) , 

ts = collect(solution_FMPy[i][1] for i in 1:length(solution_FMPy))
ss = collect(solution_FMPy[i][2] for i in 1:length(solution_FMPy))
vs = collect(solution_FMPy[i][3] for i in 1:length(solution_FMPy))

@test length(solution_FMPy) == 1001

@test isapprox(ts[1], t_start; atol=1e-6)
@test isapprox(ss[1], 1.0; atol=1e-6)
@test isapprox(vs[1], 0.0; atol=1e-6)

@test isapprox(ts[end], t_stop; atol=1e-6)
@test isapprox(ss[end], 0.23272552; atol=1e-6)
@test isapprox(vs[end], -0.17606235; atol=1e-6)

plot(ts, ss)
plot(ts, vs)

# ToDo: enable the following line
#rm(fmu_save_path)