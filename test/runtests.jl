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
        include(joinpath(@__DIR__, "FMI2", "BouncingBall", "src", "BouncingBall.jl"))

        @test isfile(fmu_save_path)
        
        # ToDo: simulate FMU in e.g. Python / FMPy
    end
end

@testset "FMIExport.jl" begin
    if Sys.iswindows() || Sys.islinux() || Sys.isapple()
        @info "Automated testing is supported on Windows/Linux/Mac."
        runtests()
    end
end