#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

FC = FMIExport.FMICore
S2 = FMIExport.FMI2Symbols
S3 = FMIExport.FMI3Symbols

# both modules export the same names
@test Set(setdiff(names(S2), [:FMI2Symbols])) == Set(setdiff(names(S3), [:FMI3Symbols]))

@test S2.fmiReal == FC.fmi2Real && S3.fmiReal == FC.fmi3Float64
@test S2.fmiComponent == FC.fmi2Component && S3.fmiComponent == FC.fmi3Instance
@test S2.fmiTrue == FC.fmi2True && S3.fmiTrue == FC.fmi3True
@test S2.createFMUSimple === createFMU2Simple && S3.createFMUSimple === createFMU3Simple

# a getter that returns 42.0 for all value references (with the additional argument `nValues` in FMI 3)
function getReal42(c, vr, nvr, value, nValues...)
    for i = 1:nvr
        unsafe_store!(value, 42.0, i)
    end
    return Cuint(0)
end

for (S, field, flag) in
    ((S2, :cGetReal, :canGetAndSetFMUstate), (S3, :cGetFloat64, :canGetAndSetFMUState))
    fmu = S.createFMU()

    # `setFctGetReal` also sets `fmi3GetFloat64` for FMI 3, the version-independent call passes `nValues`
    setFctGetReal(fmu, getReal42)
    @test S.cGetReal(fmu) == getfield(fmu, field) != C_NULL
    value = zeros(S.fmiReal, 2)
    @test S.fmiGetReal!(S.cGetReal(fmu), C_NULL, UInt32[1, 2], Csize_t(2), value) ==
          S.fmiStatusOK
    @test value == [42.0, 42.0]

    # capability flags are set by their FMI 3 names
    addModelExchange(fmu)
    S.setCapabilities!(fmu.modelDescription.modelExchange; canGetAndSetFMUState = true)
    @test getproperty(fmu.modelDescription.modelExchange, flag) == true
end
