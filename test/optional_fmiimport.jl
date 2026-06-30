#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

using FMIExport
using Test

@test Base.get_extension(FMIExport, :FMIImportExt) === nothing

caught = try
    createFMU2Simple(type = FMIExport.FMICore.fmi2TypeCoSimulation)
    nothing
catch err
    err
end

@test caught isa ArgumentError
@test occursin("FMIImport required for CS FMU export", sprint(showerror, caught))

using FMIImport

@test Base.get_extension(FMIExport, :FMIImportExt) !== nothing
