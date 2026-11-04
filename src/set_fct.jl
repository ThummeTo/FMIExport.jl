#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

# [Note] `@cfunction($fun, ...)` returns a `CFunction` object that owns the code behind its pointer,
#        the code is freed when the object is garbage collected. Therefore, the `CFunction` objects
#        are stored as long as the FMU (that holds the pointers) exists.
const FMU_CFUNCTIONS = WeakKeyDict{FMU,Vector{Base.CFunction}}()

# stores `c_fun` for the lifetime of `fmu` and sets its pointer as the FMU function `field`
function storeCFunction!(fmu::FMU, field::Symbol, c_fun::Base.CFunction)
    push!(get!(Vector{Base.CFunction}, FMU_CFUNCTIONS, fmu), c_fun)
    setproperty!(fmu, field, c_fun.ptr)
    return c_fun.ptr
end
