#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

include(joinpath("$(@__DIR__)", "..", "example", "FMI2", "BouncingBall", "src", "BouncingBall.jl"))
@test isfile(fmu_save_path)