#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

using FMIExport
using Test

function runtests()
    @testset "Model Description" begin
        include("model_description.jl")
    end

    @testset "Bouncing Ball" begin
        include("bouncing_ball.jl")
    end

    @testset "FMU Manipulation" begin
        #@warn "The test `FMU Manipulation` is currently excluded because of insufficient ressources in GitHub-Actions."
        include("manipulation.jl")
    end

    @testset "NeuralFMU" begin
        #@warn "The test `NeuralFMU` is currently excluded because of insufficient ressources in GitHub-Actions."
        include("neuralFMU.jl")
    end
end

@testset "FMIExport.jl" begin
    if Sys.iswindows() || Sys.islinux() || Sys.isapple()
        @info "Automated testing is supported on Windows/Linux/Mac."
        runtests()
    end
end