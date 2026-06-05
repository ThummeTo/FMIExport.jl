# Create a FMU
at the example of the well-known *bouncing ball*

Tutorial by Tobias Thummerer, Simon Exner | Last edit: February 2025

🚧 This is still WIP and we add additional information and description, soon! 🚧

## License


```julia
#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#
```

## Introduction

This Julia Package FMIExport.jl enables the export of simulation models from Julia code. The FMI (Functional Mock-up Interface) is a free standard ([fmi-standard.org](https://fmi-standard.org)) that defines a *model container* and an interface to exchange simulation models using a combination of XML files, binaries and C code zipped into a single file. The magic on the Julia side happens by compiling Julia code to a DLL (Windows) or LIB (Linux) by using the *PackageCompiler.jl*, therefore a *package* is defined to be compiled - instead of just a single file. This is very important to keep in mind.

## Getting started 
To allow for editing the example, you can make a copy of the examples folder. In case you just want to lean back and enjoy the magic, you can proceed by just *opening* the bouncing ball example. 

In the creation of the FMU, an entire package is involved. However, the things that need to be defined by you can happen within only a single file. In case of the bouncing ball, this file is [BouncingBall.jl](https://github.com/ThummeTo/FMIExport.jl/blob/main/examples/FMI2/BouncingBall/src/BouncingBall.jl). If we have a look inside, we find many interesting things, that we investigate in detail now. The code in the following only investigates *snippets*, for full running code see the [examples folder](https://github.com/ThummeTo/FMIExport.jl/blob/main/examples/).

We start by loading the library.


```julia
using FMIExport
using FMIExport.FMIBase.FMICore: fmi2True, fmi2False, fmi2Integer
```

Further, we define a start state and initial parameters.


```julia
# a minimum height to reset the ball after event
EPS = 1e-8

# ball position, velocity (initial)
DEFAULT_X0 = [1.0, 0.0]
# ball mass, ball radius, ball collision damping, ball minimum velocity, gravity constant 
DEFAULT_PARAMS = [1.0, 0.1, 0.9, 1e-3, 9.81]
```




    5-element Vector{Float64}:
     1.0
     0.1
     0.9
     0.001
     9.81



### Initialization function
For solving IVPs (initial value problems), we require an *inital value* - for ODEs, this is the initial state. Therefore, we define a function, that computes (or just returns) a start state to start the algorithm for numerical integration to obtain a solution.


```julia
FMU_FCT_INIT = function()
   
    sticking = fmi2False
    counter = fmi2Integer(0)

    s = DEFAULT_X0[1]         # ball position
    v = DEFAULT_X0[2]         # ball velocity
    a = 0.0                   # ball acceleration

    t = 0.0        
    x_c = [s, v]      
    ẋ_c = [v, a]
    x_d = [sticking, counter]
    u = []
    p = DEFAULT_PARAMS

    return (t, x_c, ẋ_c, x_d, u, p)
end
```




    #1 (generic function with 1 method)



### Function for the right-hand side
After we defined start values for the integration, we need to define what is actually integrated. For ODEs, this is refered to as the *right-hand side*, a function, that defines derivatives that are numerically integrated by the ODE solver.


```julia
FMU_FCT_EVALUATE = function(t, x_c, ẋ_c, x_d, u, p, eventMode)
    m, r, d, v_min, g = p
    s, v = x_c
    sticking, counter = x_d
    _, a = ẋ_c

    if sticking == fmi2True
        a = 0.0
    elseif sticking == fmi2False

        if eventMode
            h = s-r
            if h <= 0 && v < 0
                s = r + EPS # so that indicator is not triggered again
                v = -v*d 
                counter = fmi2Integer(counter+1)

                # stop bouncing to prevent high frequency bouncing (and maybe tunneling the floor)
                if abs(v) < v_min
                    sticking = fmi2True
                    v = 0.0
                end
            end
        end

        a = (m * -g) / m     # the system's physical equation (a little longer than necessary)
    else
        @error "Unknown value for `sticking` == $(sticking)."
        return (x_c, ẋ_c, x_d, p)
    end

    # Todo: Remove these allocations. Make it inplace.
    x_c = [s, v]
    ẋ_c = [v, a]
    x_d = [sticking, counter]
    p = [m, r, d, v_min, g]

    return (x_c, ẋ_c, x_d, p)
end
```




    #3 (generic function with 1 method)



### Event indicator function
We defined what happens if we collide with the ground, but we need a way to tell the solver *when exactly* this is the case - so a mathematical definition of the collision. This happens within the *event indicator*: Whenever we have a real zero crossing within the event indicator, the solver (or the event finding routine within) searches for the exact event location and pauses the integration process here. After the event is handled (and the ball velocity changed), the numerical integration resumes with the new state.


```julia
FMU_FCT_EVENT = function(t, x_c, ẋ_c, x_d, u, p)
    m, r, d, v_min, g = p
    s, v = x_c
    _, a = ẋ_c
    sticking, counter = x_d

    # helpers
    z1 = 0.0 # first event indicator
    h = s-r # ball height

    if sticking == fmi2True
        z1 = 1.0            # event 1: ball stay-on-ground
    else
        if h > -EPS && h <= 0 && v > 0
            z1 = -EPS
        else 
            z1 = h
        end
    end

    z = [z1]

    return z
end
```




    #5 (generic function with 1 method)



### Output function

Finally, we can define *outputs* that are exposed to the user. In FMI, in theory, we could investigate all quantities we are interested in (if not explicitly hidden by the FMU), however it makes sense to define or calculate application specific outputs. In this case, we just return the ball position and velocity.


```julia
FMU_FCT_OUTPUT = function(t, x_c, ẋ_c, x_d, u, p)
    m, r, d, v_min, g = p
    s, v = x_c
    _, a = ẋ_c
    sticking, counter = x_d

    y = [s, v]

    return y
end
```




    #7 (generic function with 1 method)



### FMU constructor
After defining the mathematical behavior for our FMU, we need to define a constructor - so a function that is called if the FMU is loaded. Within, we define all the variables we want to be part of the *model description*, technically a XML that exposes the model structure and variables. This XML is parsed by importing tools to simulate FMUs appropriately and to provide helpful information.


```julia
FMIBUILD_CONSTRUCTOR = function(resPath="")
    fmu = fmi2CreateSimple(initializationFct=FMU_FCT_INIT,
                        evaluationFct=FMU_FCT_EVALUATE,
                        outputFct=FMU_FCT_OUTPUT,
                        eventFct=FMU_FCT_EVENT)

    fmu.modelDescription.modelName = "BouncingBall"

    # modes 
    fmi2ModelDescriptionAddModelExchange(fmu.modelDescription, "BouncingBall")

    # states [2]
    fmi2AddStateAndDerivative(fmu, "ball.s"; stateStart=DEFAULT_X0[1], stateDescr="Absolute position of ball center of mass", derivativeDescr="Absolute velocity of ball center of mass")
    fmi2AddStateAndDerivative(fmu, "ball.v"; stateStart=DEFAULT_X0[2], stateDescr="Absolute velocity of ball center of mass", derivativeDescr="Absolute acceleration of ball center of mass")

    # discrete state [2]
    fmi2AddIntegerDiscreteState(fmu, "sticking"; description="Indicator (boolean) if the mass is sticking on the ground, as soon as abs(v) < v_min")
    fmi2AddIntegerDiscreteState(fmu, "counter"; description="Number of collision with the floor.")

    # outputs [2]
    fmi2AddRealOutput(fmu, "ball.s_out"; description="Absolute position of ball center of mass")
    fmi2AddRealOutput(fmu, "ball.v_out"; description="Absolute velocity of ball center of mass")

    # parameters [5]
    fmi2AddRealParameter(fmu, "m";     start=DEFAULT_PARAMS[1], description="Mass of ball")
    fmi2AddRealParameter(fmu, "r";     start=DEFAULT_PARAMS[2], description="Radius of ball")
    fmi2AddRealParameter(fmu, "d";     start=DEFAULT_PARAMS[3], description="Collision damping constant (velocity fraction after hitting the ground)")
    fmi2AddRealParameter(fmu, "v_min"; start=DEFAULT_PARAMS[4], description="Minimal ball velocity to enter on-ground-state")
    fmi2AddRealParameter(fmu, "g";     start=DEFAULT_PARAMS[5], description="Gravity constant")

    fmi2AddEventIndicator(fmu)

    return fmu
end
```




    #9 (generic function with 2 methods)



## Building the FMU
The compilation process for the FMU is triggered by the following lines. Keep in mind, that the entire package is compiled to an FMU. If we trigger the building process within this package, we would create a FMU that compiles FMU... this sounds cool at first glance, but is not what we want in most cases. Therefore, the build command itself `saveFMU` is within a formatted block, starting with `### FMIBUILD_NO_EXPORT_BEGIN ###` and ending with `### FMIBUILD_NO_EXPORT_END ###`. All text between these delimiters is automatically removed *before* building of the package happens. This way, the actual building package `FMIBuild` and the build command are excluded from the final FMU. Alternatively, one could trigger the build process from outside the package, e.g. by working in the REPL directly. The command `saveFMU` is commented out, to not start a building process within this notebook - this must be included in your application of course.


```julia
### FMIBUILD_NO_EXPORT_BEGIN ###
# The line above is a start-marker for excluded code for the FMU compilation process!

tmpDir = mktempdir(; prefix="fmibuildjl_test_", cleanup=false) 
@info "Saving example files at: $(tmpDir)"
fmu_save_path = joinpath(tmpDir, "BouncingBall.fmu")  

fmu = FMIBUILD_CONSTRUCTOR()
using FMIBuild: saveFMU                    # <= this must be excluded during export, because FMIBuild cannot execute itself (but it is able to build)
# saveFMU(fmu, fmu_save_path; debug=true, compress=false)    # <= this must be excluded during export, because saveFMU would start an infinite build loop with itself (debug=true allows debug messages, but is slow during execution!)

# The following line is a end-marker for excluded code for the FMU compilation process!
### FMIBUILD_NO_EXPORT_END ###
```

    [36m[1m[ [22m[39m[36m[1mInfo: [22m[39mSaving example files at: C:\Users\RUNNER~1\AppData\Local\Temp\fmibuildjl_test_P99m5m
    

## Simulate the FMU 
FMUs exported and compiled with Julia **can not** be executed within Julia. This sounds wired, but comes from the fact that only a single Julia instance (sysimage) is allowed to run for each Julia process. However, you can use FMUs from Julia within any other tool that supports FMI, of course.

Interestingly, there is actually no need to *compile* a FMU if you want to use it within Julia anyway - you can just use the current copy within the memory with *FMI.jl*, see the following lines.


```julia
using FMI, DifferentialEquations
fmu.executionConfig.loggingOn = true
solution = simulate(fmu, (0.0, 3.0); recordValues=["sticking", "counter"])

using Plots
plot(solution)
```

    [32m[1mPrecompiling[22m[39m packages...

    
    

       2320.9 ms[32m  ✓ [39m[90mLinearSolve → LinearSolveChainRulesCoreExt[39m
    

      1 dependency successfully precompiled in 5 seconds. 89 already precompiled.

    
    [33m[1m┌ [22m[39m[33m[1mWarning: [22m[39mfmi2Instantiate!(...): This component was already registered. This may be because you created the FMU by yourself with FMIExport.jl.
    [33m[1m└ [22m[39m[90m@ FMIBase C:\Users\runneradmin\.julia\packages\FMIBase\3xLW8\src\printing.jl:30[39m
    

    [34mSimulating ME-FMU ...   0%|█                             |  ETA: N/A[39m

    [34mSimulating ME-FMU ...   0%|█                             |  ETA: N/A[39m

    [34mSimulating ME-FMU ... 100%|██████████████████████████████| Time: 0:00:15[39m
    

    [33m[1m┌ [22m[39m[33m[1mWarning: [22m[39mUnknown instance at Ptr{Nothing} @0x000002163daf5990.
    [33m[1m└ [22m[39m[90m@ FMIExport D:\a\FMIExport.jl\FMIExport.jl\src\FMI2_simple.jl:40[39m
    




<img src="data:image/png;base64,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" />



## Getting started with custom project
The best way to start with your own project, is to make a *copy* of one of the example *folders*, for example the bouncing ball and edit it to fit you requirements. Because the entire package is compiled, you can control the size of the binary by adding or removing packages to the *Project.toml*. You can use *Pkg.jl* of course to manage dependencies. Then you can start overwriting the functions, that define the right-hand side of you FMU, events and event indicators and finally the output variables.
