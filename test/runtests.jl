#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

using FMIExport
using Test

@testset "FMIExport.jl" begin
    if Sys.iswindows()
        @info "Automated testing is supported on Windows/Linux/Mac."
    
        @testset "Model Description" begin
            include("model_description.jl")
        end
    
        @testset "Bouncing Ball" begin
            include(joinpath("bouncing_ball", "bouncing_ball.jl"))
        end
    
        @testset "FMU Manipulation" begin
            #@warn "The test `FMU Manipulation` is currently excluded because of insufficient resources in GitHub-Actions."
            include("manipulation.jl")
        end
    
        @testset "NeuralFMU" begin
            #@warn "The test `NeuralFMU` is currently excluded because of insufficient resources in GitHub-Actions."
            include("neuralFMU.jl")
        end

    elseif Sys.islinux() || Sys.isapple()
        @warn "Tests not supported on Linux and Mac."
    else
        @warn "Tests not supported on `unknown operation system`."
    end
end