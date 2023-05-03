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

    # CI Fails with more than one testing compilation (probably disc memory), test running locally
    # @testset "FMU Manipulation" begin
    #     include("manipulation.jl")
    # end

    # @testset "NeuralFMU" begin
    #     include("neuralFMU.jl")
    # end
end

@testset "FMIExport.jl" begin
    if Sys.iswindows() || Sys.islinux() || Sys.isapple()
        @info "Automated testing is supported on Windows/Linux/Mac."
        runtests()
    end
end