using PkgEval
using FMIExport

config = Configuration(; julia = "1.10");

package = Package(; name = "FMIExport");

@info "PkgEval"
result = evaluate([config], [package])

@info "Result"
println(result)

@info "Log"
println(result.log)
