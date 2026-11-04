#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

module FMIExport

using FMIBase
using FMIBase.FMICore
using FMIBase.FMICore: FMI2_SCALAR_VARIABLE_ATTRIBUTE_STRUCT

include("md.jl")
include("FMI2/md.jl")
include("FMI2/simple.jl")

include("FMI3/md.jl")
include("FMI3/simple.jl")

include("ANN.jl")
include("set_fct.jl")
include("FMI2/set_fct.jl")
include("FMI3/set_fct.jl")
include("create.jl")

# version-independent names for FMI 2 and FMI 3
include("FMI2/symbols.jl")
include("FMI3/symbols.jl")

end # module
