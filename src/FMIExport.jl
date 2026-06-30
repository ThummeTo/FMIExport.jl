#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

module FMIExport

using FMIBase
using FMIBase.FMICore
using FMIBase.FMICore: FMI2_SCALAR_VARIABLE_ATTRIBUTE_STRUCT
import OrdinaryDiffEq

include("FMI2/md.jl")
include("FMI2/simple.jl")

include("ANN.jl")
include("set_fct.jl")
include("create.jl")

end # module
