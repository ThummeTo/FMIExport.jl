# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher, Johannes Stoljar
# Licensed under the MIT license.
# See LICENSE (https://github.com/thummeto/FMIExport.jl/blob/main/LICENSE) file in the project root for details.

using FMIExport
using FMIBuild: saveFMU

tmpDir = mktempdir(; prefix="fmibuildjl_test_", cleanup=false) 
@info "Saving example files at: $(tmpDir)"
fmu_save_path = joinpath(tmpDir, "BouncingBall.fmu")  

working_dir = pwd() # current working directory
println(string("pwd() returns: ", working_dir))

package_dir = split(working_dir, joinpath("examples", "jupyter-src"))[1] # remove everything after and including "examples\jupyter-src"
println(string("package_dir is ", package_dir))

fmu_source_package = joinpath(package_dir, "examples", "FMI2", "BouncingBall") # add correct relative path
println(string("fmu_source_package is ", fmu_source_package))

fmu_source_path = joinpath(fmu_source_package, "src", "BouncingBall.jl") # add correct relative path
println(string("fmu_source_path is ", fmu_source_path))

using FMIExport.FMIBase.FMICore: fmi2True, fmi2False 

EPS = 1e-6

FMU_FCT_INIT = function()
    m = 1.0         # ball mass
    r = 0.0         # ball radius
    d = 0.7         # ball collision damping
    v_min = 1e-1    # ball minimum velocity
    g = 9.81        # gravity constant 
    sticking = fmi2False

    s = 1.0         # ball position
    v = 0.0         # ball velocity
    a = 0.0         # ball acceleration

    t = 0.0        
    x_c = [s, v]      
    ẋ_c = [v, a]
    x_d = [sticking]
    u = []
    p = [m, r, d, v_min, g]

    return (t, x_c, ẋ_c, x_d, u, p)
end

FMU_FCT_EVALUATE = function(t, x_c, ẋ_c, x_d, u, p, eventMode)
    m, r, d, v_min, g = p
    s, v = x_c
    sticking = x_d[1]
    _, a = ẋ_c

    if sticking == fmi2True
        a = 0.0
    elseif sticking == fmi2False
        if eventMode
            if s < r && v < 0.0
                s = r + EPS # so that indicator is not triggered again
                v = -v*d 
                
                # stop bouncing to prevent high frequency bouncing (and maybe tunneling the floor)
                if abs(v) < v_min
                    sticking = fmi2True
                    v = 0.0
                end
            end
        else
            # no specials in continuos time mode
        end

        a = (m * -g) / m     # the system's physical equation (a little longer than necessary)
    else
        @error "Unknown value for `sticking` == $(sticking)."
        return (x_c, ẋ_c, x_d, p)
    end

    x_c = [s, v]
    ẋ_c = [v, a]
    x_d = [sticking]
    p = [m, r, d, v_min, g]

    return (x_c, ẋ_c, x_d, p) # evaluation can't change discrete state!
end

FMU_FCT_OUTPUT = function(t, x_c, ẋ_c, x_d, u, p)
    m, r, d, v_min, g = p
    s, v = x_c
    _, a = ẋ_c
    sticking = x_d[1]

    y = [s]

    return y
end

FMU_FCT_EVENT = function(t, x_c, ẋ_c, x_d, u, p)
    m, r, d, v_min, g = p
    s, v = x_c
    _, a = ẋ_c
    sticking = x_d[1]
   
    if sticking == fmi2True
        z1 = 1.0            # event 1: ball stay-on-ground
    else
        z1 = (s-r)          # event 1: ball hits ground 
    end

    z = [z1]

    return z
end
FMIBUILD_CONSTRUCTOR = function(resPath="")
    fmu = fmi2CreateSimple(initializationFct=FMU_FCT_INIT,
                        evaluationFct=FMU_FCT_EVALUATE,
                        outputFct=FMU_FCT_OUTPUT,
                        eventFct=FMU_FCT_EVENT)

    fmu.modelDescription.modelName = "BouncingBall"

    # modes 
    fmi2ModelDescriptionAddModelExchange(fmu.modelDescription, "BouncingBall")

    # states [2]
    fmi2AddStateAndDerivative(fmu, "ball.s"; stateDescr="Absolute position of ball center of mass", derivativeDescr="Absolute velocity of ball center of mass")
    fmi2AddStateAndDerivative(fmu, "ball.v"; stateDescr="Absolute velocity of ball center of mass", derivativeDescr="Absolute acceleration of ball center of mass")

    # discrete state [1]
    fmi2AddIntegerDiscreteState(fmu, "sticking"; description="Indicator (boolean) if the mass is sticking on the ground, as soon as abs(v) < v_min")

    # outputs [1]
    fmi2AddRealOutput(fmu, "ball.s_out"; description="Absolute position of ball center of mass")

    # parameters [5]
    fmi2AddRealParameter(fmu, "m";     description="Mass of ball")
    fmi2AddRealParameter(fmu, "r";     description="Radius of ball")
    fmi2AddRealParameter(fmu, "d";     description="Collision damping constant (velocity fraction after hitting the ground)")
    fmi2AddRealParameter(fmu, "v_min"; description="Minimal ball velocity to enter on-ground-state")
    fmi2AddRealParameter(fmu, "g";     description="Gravity constant")

    fmi2AddEventIndicator(fmu)

    return fmu
end
fmu = FMIBUILD_CONSTRUCTOR()

using Pkg
notebook_env = Base.active_project(); # save current enviroment to return to it after we are done
Pkg.activate(fmu_source_package); # activate the FMUs enviroment

# make shure to use the same FMI source as in the enviroment of this example ("notebook_env"). 
# As this example is automattically built using the local FMIExport package and not the one from the Juila registry, we need to add it using "develop". 
Pkg.develop(PackageSpec(path=package_dir)); # If you added FMIExport using "add FMIExport", you have to remove this line and use instantiate instead.
# Pkg.instantiate(); # instantiate the FMUs enviroment only if develop was not previously called

Pkg.activate(notebook_env); # return to the original notebooks enviroment

# currently export is broken, therefor we will not do it
#saveFMU(fmu, fmu_save_path, fmu_source_path; debug=false, compress=false) # feel free to set debug true, disabled for documentation building
#saveFMU(fmu_save_path, fmu_source_path; debug=false, compress=false) this meight be the format after the next release

mkpath("Export_files")
# currently export is broken, therefor we will not find anything there
#cp(fmu_save_path, joinpath("Export_files", "BouncingBall.fmu"))
