# Create a Bouncing Ball FMU
Tutorial by Johannes Stoljar, Tobias Thummerer

## License


```julia
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher, Johannes Stoljar
# Licensed under the MIT license.
# See LICENSE (https://github.com/thummeto/FMIExport.jl/blob/main/LICENSE) file in the project root for details.
```

## Motivation
This Julia Package *FMIExport.jl* is motivated by the export of simulation models in Julia. Here the FMI specification is implemented. FMI (*Functional Mock-up Interface*) is a free standard ([fmi-standard.org](http://fmi-standard.org/)) that defines a container and an interface to exchange dynamic models using a combination of XML files, binaries and C code zipped into a single file. The user is able to create own FMUs (*Functional Mock-up Units*).

## Introduction to the example
ToDo


## Target group
The example is primarily intended for users who work in the field of simulations. The example wants to show how simple it is to export FMUs in Julia.


## Other formats
Besides, this [Jupyter Notebook](https://github.com/thummeto/FMIExport.jl/blob/examples/examples/FMI2/BouncingBall/src/BouncingBall.ipynb) there is also a [Julia file](https://github.com/thummeto/FMIExport.jl/blob/examples/examples/FMI2/BouncingBall/src/BouncingBall.jl) with the same name, which contains only the code cells and for the documentation there is a [Markdown file](https://github.com/thummeto/FMI.jl/blob/examples/examples/FMI2/BouncingBall/src/BouncingBall.md) corresponding to the notebook.  


## Getting started

### Installation prerequisites
|     | Description                       | Command                   | Alternative                                    |   
|:----|:----------------------------------|:--------------------------|:-----------------------------------------------|
| 1.  | Enter Package Manager via         | ]                         |                                                |
| 2.  | Install FMIExport via             | add FMIExport             | add " https://github.com/ThummeTo/FMIExport.jl " |

## Code section

To run the example, the previously installed packages must be included. 


```julia
using FMIExport 
```

### Define the Model

In the following section the behavior of the FMU is defined by defining the functions for initialization, evaluation, output and event.


```julia
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
```




    #7 (generic function with 1 method)



### FMU Constructor

This function is called, as soon as the DLL is loaded and Julia is initialized. The function must return a FMU2-instance to work with.


```julia
FMIBUILD_CONSTRUCTOR = function(resPath=".")
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
# using FMIBuild: fmi2Save        # <= this must be excluded during export, because FMIBuild cannot execute itself (but it is able to build)
# fmi2Save(fmu, fmu_save_path)    # <= this must be excluded during export, because fmi2Save would start an infinte build loop with itself 

### some tests ###
# using FMI
# comp = fmiInstantiate!(fmu; loggingOn=true)
# solution = fmiSimulateME(comp, 0.0, 10.0; dtmax=0.1)
# fmiPlot(fmu, solution)
# fmiFreeInstance!(comp)

# The following line is a end-marker for excluded code for the FMU compilation process!
### FMIBUILD_NO_EXPORT_END ###
```

    ┌ Info: Saving example files at: /tmp/fmibuildjl_test_DpMkmy
    └ @ Main In[4]:30





    Model name:        
    Type:              0



### Summary

Based on this tutorial it can be seen that creating an FMU is very easy.
