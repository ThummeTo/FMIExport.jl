#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

using FMIExport 

FMU_FCT_INIT = function()
    m = 1.0         # ball mass
    r = 0.0         # ball radius
    d = 0.7         # ball collision damping
    v_min = 1e-1    # ball minimum velocity
    g = -9.81       # gravity constant 

    s = 1.0         # ball position
    v = 0.0         # ball velocity
    a = 0.0         # ball acceleration

    t = 0.0        
    x = [s, v]      
    ẋ = [v, a]
    u = []
    p = [m, r, d, v_min, g]

    return (t, x, ẋ, u, p)
end

FMU_FCT_EVALUATE = function(t, x, ẋ, u, p)
    m, r, d, v_min, g = (p...,)
    s, v = (x...,)
    _, a = (ẋ...,)

    if s <= r && v < 0.0
        s = r
        v = -v*d 
        
        # stop bouncing to prevent high frequency bouncing (and maybe tunneling the floor)
        if v < v_min
            v = 0.0
            g = 0.0
        end
    end

    a = (m * g) / m     # the system's physical equation

    x = [s, v]
    ẋ = [v, a]
    p = [m, r, d, v_min, g]

    return (x, ẋ, p)
end

FMU_FCT_OUTPUT = function(t, x, ẋ, u, p)
    m, r, d, v_min, g = (p...,)
    s, v = (x...,)
    _, a = (ẋ...,)

    y = [s]

    return y
end

FMU_FCT_EVENT = function(t, x, ẋ, u, p)
    m, r, d, v_min, g = (p...,)
    s, v = (x...,)
    _, a = (ẋ...,)

    z1 = (s-r)              # event 1: ball hits ground 
   
    if s==r && v==0.0
        z1 = 1.0            # event 1: ball stay-on-ground
    end

    z = [z1]

    return z
end

# this function is called, as soon as the DLL is loaded and Julia is initialized 
# must return a FMU2-instance to work with
FMIBUILD_CONSTRUCTOR = function(resPath="")
    fmu = fmi2CreateSimple(initializationFct=FMU_FCT_INIT,
                        evaluationFct=FMU_FCT_EVALUATE,
                        outputFct=FMU_FCT_OUTPUT,
                        eventFct=FMU_FCT_EVENT)

    # states [2]
    fmi2AddStateAndDerivative(fmu, "ball.s"; stateDescr="Absolute position of ball center of mass", derivativeDescr="Absolute velocity of ball center of mass")
    fmi2AddStateAndDerivative(fmu, "ball.v"; stateDescr="Absolute velocity of ball center of mass", derivativeDescr="Absolute acceleration of ball center of mass")

    # outputs [1]
    fmi2AddRealOutput(fmu, "ball.s"; description="Absolute position of ball center of mass")

    # parameters [5]
    fmi2AddRealParameter(fmu, "m";     description="Mass of ball")
    fmi2AddRealParameter(fmu, "r";     description="Radius of ball")
    fmi2AddRealParameter(fmu, "d";     description="Collision damping constant (velocity fraction after hitting the ground)")
    fmi2AddRealParameter(fmu, "v_min"; description="Minimal ball velocity to enter on-ground-state")
    fmi2AddRealParameter(fmu, "g";     description="Gravity constant")

    fmi2AddEventIndicator(fmu)

    return fmu
end

### FMIBUILD_NO_EXPORT_BEGIN ###
# The line above is a start-marker for excluded code for the FMU compilation process!

tmpDir = mktempdir(; prefix="fmibuildjl_test_", cleanup=false) 
@info "Saving example files at: $(tmpDir)"
fmu_save_path = joinpath(tmpDir, "BouncingBall.fmu")  

fmu = FMIBUILD_CONSTRUCTOR()
using FMIBuild: fmi2Save        # <= this must be excluded during export, because FMIBuild cannot execute itself (but it is able to build)
fmi2Save(fmu, fmu_save_path)    # <= this must be excluded during export, because fmi2Save would start an infinte build loop with itself 

### some tests ###
# using FMI
# comp = fmiInstantiate!(fmu; loggingOn=true)
# solution = fmiSimulateME(comp, 0.0, 10.0; dtmax=0.1)
# fmiPlot(fmu, solution)
# fmiFreeInstance!(comp)

# The following line is a end-marker for excluded code for the FMU compilation process!
### FMIBUILD_NO_EXPORT_END ###
