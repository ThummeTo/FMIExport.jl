#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

using FMI
using FMIExport
using FMICore

originalGetReal = nothing # function pointer to the original fmi2GetReal c-function

# custom function for fmi2GetReal!(fmi2Component, Union{Array{fmi2ValueReference}, Ptr{fmi2ValueReference}}, Csize_t, value::Union{Array{fmi2Real}, Ptr{fmi2Real}}::fmi2Status
# for information on how the FMI2-functions are structured, have a look inside FMICore.jl/src/FMI2_c.jl or the FMI2.0.3-specification on fmi-standard.org
function myGetReal!(c::fmi2Component, vr::Union{Array{fmi2ValueReference}, Ptr{fmi2ValueReference}}, nvr::Csize_t, value::Union{Array{fmi2Real}, Ptr{fmi2Real}})
    global originalGetReal
    
    # first, we do what the original function does
    status = fmi2GetReal!(originalGetReal, c, vr, nvr, value)

    # if we have a pointer to an array, we must interprete it as array to access elements
    if isa(value, Ptr{fmi2Real})
        value = unsafe_wrap(Array{fmi2Real}, value, nvr, own=false)
    end
    if isa(vr, Ptr{fmi2Real})
        vr = unsafe_wrap(Array{fmi2Real}, vr, nvr, own=false)
    end

    # now, we multiply the position sensor output by two (just for fun!)
    for i in 1:nvr 
        if vr[i] == 335544320 # value reference for "positionSensor.s"
            value[i] *= 2.0 
        end
    end 

    # ... and we return the original status
    return status
end

# this function is called, as soon as the DLL is loaded and Julia is initialized 
# must return a FMU2-instance to work with
FMIBUILD_CONSTRUCTOR = function(resPath)
    global originalGetReal

    # loads an existing FMU inside the FMU
    fmu = fmiLoad(joinpath(resPath, "SpringDamperPendulum1D.fmu"))

    # save, where the original `fmi2GetReal` function was stored, so we can access it in our new function
    originalGetReal = fmu.cGetReal

    # now we overwrite the original function
    fmiSetFctGetReal(fmu, myGetReal!)

    return fmu
end

### FMIBUILD_NO_EXPORT_BEGIN ###
# The line above is a start-marker for excluded code for the FMU compilation process!

import FMIZoo

tmpDir = mktempdir(; prefix="fmibuildjl_test_", cleanup=false) 
@info "Saving example files at: $(tmpDir)"
fmu_save_path = joinpath(tmpDir, "Manipulation.fmu")  

sourceFMU = FMIZoo.get_model_filename("SpringDamperPendulum1D", "Dymola", "2022x")
fmu = FMIBUILD_CONSTRUCTOR(dirname(sourceFMU))
import FMIBuild:fmi2Save        # <= this must be excluded during export, because FMIBuild cannot execute itself (but it is able to build)
fmi2Save(fmu, fmu_save_path; resources=Dict(sourceFMU=>"SpringDamperPendulum1D.fmu"))    # <= this must be excluded during export, because fmi2Save would start an infinte build loop with itself 

# The following line is a end-marker for excluded code for the FMU compilation process!
### FMIBUILD_NO_EXPORT_END ###
