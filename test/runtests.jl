#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#
using FMIExport
using Test

@testset "FMIExport.jl" begin
    if Sys.iswindows() || Sys.islinux()
        @info "Automated testing is supported on Windows/Linux"

        @testset "Model Description" begin
            include("model_description.jl")
        end

        @testset "Bouncing Ball" begin
            include(joinpath("bouncing_ball", "bouncing_ball.jl"))
        end

        @testset "FMU Manipulation" begin
            # currently broken due to embedded FMUs not working
            #include(joinpath("manipulation", "manipulation.jl"))
        end

        @testset "NeuralFMU" begin
            # currently broken due to embedded FMUs not working
            #include(joinpath("neuralFMU", "neuralFMU.jl"))
        end

    elseif Sys.isapple()
        @warn "Tests not supported on Mac."
    else
        @warn "Tests not supported on `unknown operation system`."
    end
end
