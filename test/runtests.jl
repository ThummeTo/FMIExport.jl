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

end

@testset "FMIExport.jl" begin
    if Sys.iswindows() || Sys.islinux()
        @info "Automated testing is supported on Windows/Linux."
        runtests()
    elseif Sys.isapple()
        @warn "Test-sets are currrently using Windows- and Linux-FMUs, automated testing for macOS is currently not supported."
    end
end