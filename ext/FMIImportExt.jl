module FMIImportExt

using FMIBase
using FMIExport
import FMIImport

FMIExport._enable_cs_export(::FMIBase.FMU2) = nothing

function FMIExport._prepare_cs_fmu(
    fmu::FMIBase.FMU2,
    component::Union{Nothing,FMIBase.FMU2Component},
    type::Symbol;
    kwargs...,
)
    return FMIImport.prepareSolveFMU(fmu, component, type; kwargs...)
end

end # module FMIImportExt
