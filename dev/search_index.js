var documenterSearchIndex = {"docs":
[{"location":"examples/Manipulation/#Create-a-Manipulation-FMU","page":"Manipulation","title":"Create a Manipulation FMU","text":"","category":"section"},{"location":"examples/Manipulation/","page":"Manipulation","title":"Manipulation","text":"Tutorial by Johannes Stoljar, Tobias Thummerer","category":"page"},{"location":"examples/Manipulation/#License","page":"Manipulation","title":"License","text":"","category":"section"},{"location":"examples/Manipulation/","page":"Manipulation","title":"Manipulation","text":"# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher, Johannes Stoljar\n# Licensed under the MIT license.\n# See LICENSE (https://github.com/thummeto/FMIExport.jl/blob/main/LICENSE) file in the project root for details.","category":"page"},{"location":"examples/Manipulation/#Motivation","page":"Manipulation","title":"Motivation","text":"","category":"section"},{"location":"examples/Manipulation/","page":"Manipulation","title":"Manipulation","text":"This Julia Package FMIExport.jl is motivated by the export of simulation models in Julia. Here the FMI specification is implemented. FMI (Functional Mock-up Interface) is a free standard (fmi-standard.org) that defines a container and an interface to exchange dynamic models using a combination of XML files, binaries and C code zipped into a single file. The user is able to create own FMUs (Functional Mock-up Units).","category":"page"},{"location":"examples/Manipulation/#Introduction-to-the-example","page":"Manipulation","title":"Introduction to the example","text":"","category":"section"},{"location":"examples/Manipulation/","page":"Manipulation","title":"Manipulation","text":"ToDo","category":"page"},{"location":"examples/Manipulation/#Target-group","page":"Manipulation","title":"Target group","text":"","category":"section"},{"location":"examples/Manipulation/","page":"Manipulation","title":"Manipulation","text":"The example is primarily intended for users who work in the field of simulations. The example wants to show how simple it is to export FMUs in Julia.","category":"page"},{"location":"examples/Manipulation/#Other-formats","page":"Manipulation","title":"Other formats","text":"","category":"section"},{"location":"examples/Manipulation/","page":"Manipulation","title":"Manipulation","text":"Besides, this Jupyter Notebook there is also a Julia file with the same name, which contains only the code cells and for the documentation there is a Markdown file corresponding to the notebook.  ","category":"page"},{"location":"examples/Manipulation/#Getting-started","page":"Manipulation","title":"Getting started","text":"","category":"section"},{"location":"examples/Manipulation/#Installation-prerequisites","page":"Manipulation","title":"Installation prerequisites","text":"","category":"section"},{"location":"examples/Manipulation/","page":"Manipulation","title":"Manipulation","text":" Description Command Alternative\n1. Enter Package Manager via ] \n2. Install FMI via add FMI add \" https://github.com/ThummeTo/FMI.jl \"\n2. Install FMIExport via add FMIExport add \" https://github.com/ThummeTo/FMIExport.jl \"\n2. Install FMICore via add FMICore add \" https://github.com/ThummeTo/FMICore.jl \"","category":"page"},{"location":"examples/Manipulation/#Code-section","page":"Manipulation","title":"Code section","text":"","category":"section"},{"location":"examples/Manipulation/","page":"Manipulation","title":"Manipulation","text":"To run the example, the previously installed packages must be included. ","category":"page"},{"location":"examples/Manipulation/","page":"Manipulation","title":"Manipulation","text":"using FMI\nusing FMIExport\nusing FMICore","category":"page"},{"location":"examples/Manipulation/#ToDo","page":"Manipulation","title":"ToDo","text":"","category":"section"},{"location":"examples/Manipulation/","page":"Manipulation","title":"Manipulation","text":"originalGetReal = nothing # function pointer to the original fmi2GetReal c-function\n\n# custom function for fmi2GetReal!(fmi2Component, Union{Array{fmi2ValueReference}, Ptr{fmi2ValueReference}}, Csize_t, value::Union{Array{fmi2Real}, Ptr{fmi2Real}}::fmi2Status\n# for information on how the FMI2-functions are structured, have a look inside FMICore.jl/src/FMI2_c.jl or the FMI2.0.3-specification on fmi-standard.org\nfunction myGetReal!(c::fmi2Component, vr::Union{Array{fmi2ValueReference}, Ptr{fmi2ValueReference}}, nvr::Csize_t, value::Union{Array{fmi2Real}, Ptr{fmi2Real}})\n    global originalGetReal\n    \n    # first, we do what the original function does\n    status = fmi2GetReal!(originalGetReal, c, vr, nvr, value)\n\n    # if we have a pointer to an array, we must interprete it as array to access elements\n    if isa(value, Ptr{fmi2Real})\n        value = unsafe_wrap(Array{fmi2Real}, value, nvr, own=false)\n    end\n    if isa(vr, Ptr{fmi2Real})\n        vr = unsafe_wrap(Array{fmi2Real}, vr, nvr, own=false)\n    end\n\n    # now, we multiply the position sensor output by two (just for fun!)\n    for i in 1:nvr \n        if vr[i] == 335544320 # value reference for \"positionSensor.s\"\n            value[i] *= 2.0 \n        end\n    end \n\n    # ... and we return the original status\n    return status\nend\n\n# this function is called, as soon as the DLL is loaded and Julia is initialized \n# must return a FMU2-instance to work with\nFMIBUILD_CONSTRUCTOR = function(resPath)\n    global originalGetReal\n\n    # loads an existing FMU inside the FMU\n    fmu = fmiLoad(joinpath(resPath, \"SpringDamperPendulum1D.fmu\"))\n\n    # save, where the original `fmi2GetReal` function was stored, so we can access it in our new function\n    originalGetReal = fmu.cGetReal\n\n    # now we overwrite the original function\n    fmiSetFctGetReal(fmu, myGetReal!)\n\n    return fmu\nend\n\n### FMIBUILD_NO_EXPORT_BEGIN ###\n# The line above is a start-marker for excluded code for the FMU compilation process!\n\nimport FMIZoo\n\ntmpDir = mktempdir(; prefix=\"fmibuildjl_test_\", cleanup=false) \n@info \"Saving example files at: $(tmpDir)\"\nfmu_save_path = joinpath(tmpDir, \"Manipulation.fmu\")  \n\nsourceFMU = FMIZoo.get_model_filename(\"SpringDamperPendulum1D\", \"Dymola\", \"2022x\")\nfmu = FMIBUILD_CONSTRUCTOR(dirname(sourceFMU))\n# import FMIBuild:fmi2Save        # <= this must be excluded during export, because FMIBuild cannot execute itself (but it is able to build)\n# fmi2Save(fmu, fmu_save_path; resources=Dict(sourceFMU=>\"SpringDamperPendulum1D.fmu\"))    # <= this must be excluded during export, because fmi2Save would start an infinte build loop with itself \n\n# The following line is a end-marker for excluded code for the FMU compilation process!\n### FMIBUILD_NO_EXPORT_END ###\n","category":"page"},{"location":"examples/Manipulation/","page":"Manipulation","title":"Manipulation","text":"┌ Info: Saving example files at: /tmp/fmibuildjl_test_LhlbJV\n└ @ Main In[3]:53\n\n\n\n\n\nModel name:        SpringDamperPendulum1D\nType:              1","category":"page"},{"location":"examples/Manipulation/#Summary","page":"Manipulation","title":"Summary","text":"","category":"section"},{"location":"examples/Manipulation/","page":"Manipulation","title":"Manipulation","text":"ToDo","category":"page"},{"location":"contents/","page":"Contents","title":"Contents","text":"Depth = 2","category":"page"},{"location":"features/#Features","page":"Features","title":"Features","text":"","category":"section"},{"location":"features/","page":"Features","title":"Features","text":"Please note, that this guide focuses also on users, that are not familiar with FMI. The following feature explanations are written in an easy-to-read-fashion, so there might be some points that are scientifically only 95% correct. For further information on FMI and FMUs, see fmi-standard.org.","category":"page"},{"location":"features/#ToDo","page":"Features","title":"ToDo","text":"","category":"section"},{"location":"library/#Library-Functions","page":"Library Functions","title":"Library Functions","text":"","category":"section"},{"location":"library/#ToDo","page":"Library Functions","title":"ToDo","text":"","category":"section"},{"location":"related/#Related-Publications","page":"Related Publication","title":"Related Publications","text":"","category":"section"},{"location":"related/","page":"Related Publication","title":"Related Publication","text":"Tobias Thummerer, Josef Kircher, Lars Mikelsons 2021 NeuralFMU: Towards Structural Integration of FMUs into Neural Networks (14th Modelica Conference, Preprint, Accepted) arXiv:2109.04351","category":"page"},{"location":"related/","page":"Related Publication","title":"Related Publication","text":"Tobias Thummerer, Johannes Tintenherr, Lars Mikelsons 2021 Hybrid modeling of the human cardiovascular system using NeuralFMUs (10th International Conference on Mathematical Modeling in Physical Sciences, Preprint, Accepted) arXiv:2109.04880","category":"page"},{"location":"examples/overview/#Overview","page":"Overview","title":"Overview","text":"","category":"section"},{"location":"examples/overview/","page":"Overview","title":"Overview","text":"This section discusses the included examples of the FMI.jl library. So you can execute them on your machine and get detailed information about all the steps. If you require further information about the function calls, see the function sections of the library.","category":"page"},{"location":"examples/overview/","page":"Overview","title":"Overview","text":"The examples are:","category":"page"},{"location":"examples/overview/","page":"Overview","title":"Overview","text":"BouncingBall: BouncingBall\nManipulation: Manipulation","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"(Image: FMI.jl Logo)","category":"page"},{"location":"#FMIExport.jl","page":"Introduction","title":"FMIExport.jl","text":"","category":"section"},{"location":"#What-is-FMIExport.jl?","page":"Introduction","title":"What is FMIExport.jl?","text":"","category":"section"},{"location":"","page":"Introduction","title":"Introduction","text":"FMIExport.jl is a free-to-use software library for the Julia programming language which allows for the export of FMUs (fmi-standard.org) from any Julia-Code. FMIExport.jl is completely integrated into FMI.jl.","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"(Image: Dev Docs)  (Image: Run Tests) (Image: Run Examples) (Image: Build Docs) (Image: Coverage) (Image: ColPrac: Contributor's Guide on Collaborative Practices for Community Packages)","category":"page"},{"location":"#How-can-I-use-FMIExport.jl?","page":"Introduction","title":"How can I use FMIExport.jl?","text":"","category":"section"},{"location":"","page":"Introduction","title":"Introduction","text":"1. Open a Julia-REPL, switch to package mode using ], activate your preferred environment.","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"2. Install FMIExport.jl:","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"(@v1.6) pkg> add FMIExport","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"3. If you want to check that everything works correctly, you can run the tests bundled with FMIExport.jl:","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"(@v1.6) pkg> test FMIExport","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"4. Have a look inside the examples folder in the examples branch or the examples section of the documentation. All examples are available as Julia-Script (.jl), Jupyter-Notebook (.ipynb) and Markdown (.md).","category":"page"},{"location":"#What-FMI.jl-Library-should-I-use?","page":"Introduction","title":"What FMI.jl-Library should I use?","text":"","category":"section"},{"location":"","page":"Introduction","title":"Introduction","text":"(Image: FMI.jl Logo) To keep dependencies nice and clean, the original package FMI.jl had been split into new packages:","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"FMI.jl: High level loading, manipulating, saving or building entire FMUs from scratch\nFMIImport.jl: Importing FMUs into Julia\nFMIExport.jl: Exporting stand-alone FMUs from Julia Code\nFMICore.jl: C-code wrapper for the FMI-standard\nFMIBuild.jl: Compiler/Compilation dependencies for FMIExport.jl\nFMIFlux.jl: Machine Learning with FMUs (differentiation over FMUs)\nFMIZoo.jl: A collection of testing and example FMUs","category":"page"},{"location":"#What-Platforms-are-supported?","page":"Introduction","title":"What Platforms are supported?","text":"","category":"section"},{"location":"","page":"Introduction","title":"Introduction","text":"FMIExport.jl is tested (and testing) under Julia Versions 1.6.6 LTS and latest on Windows latest. x64 architectures are tested. Ubuntu is under development and near completion.","category":"page"},{"location":"#Known-limitations","page":"Introduction","title":"Known limitations","text":"","category":"section"},{"location":"","page":"Introduction","title":"Introduction","text":"Currently it is not possible to hold more than one sysimg in a Julia session, so it is not possible to load FMUs generated with FMIExport.jl into FMI.jl using fmiLoad(...). However, FMUs created with fmiCreate can be used in FMI.jl without the need to export and re-import it, the FMU behaves like any other FMU loaded via fmiLoad.","category":"page"},{"location":"#How-to-cite?","page":"Introduction","title":"How to cite?","text":"","category":"section"},{"location":"","page":"Introduction","title":"Introduction","text":"Tobias Thummerer, Johannes Stoljar and Lars Mikelsons. 2022. NeuralFMU: presenting a workflow for integrating hybrid NeuralODEs into real-world applications. Electronics 11, 19, 3202. DOI: 10.3390/electronics11193202","category":"page"},{"location":"#Related-publications?","page":"Introduction","title":"Related publications?","text":"","category":"section"},{"location":"","page":"Introduction","title":"Introduction","text":"Tobias Thummerer, Lars Mikelsons and Josef Kircher. 2021. NeuralFMU: towards structural integration of FMUs into neural networks. Martin Sjölund, Lena Buffoni, Adrian Pop and Lennart Ochel (Ed.). Proceedings of 14th Modelica Conference 2021, Linköping, Sweden, September 20-24, 2021. Linköping University Electronic Press, Linköping (Linköping Electronic Conference Proceedings ; 181), 297-306. DOI: 10.3384/ecp21181297","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"Tobias Thummerer, Johannes Tintenherr, Lars Mikelsons. 2021 Hybrid modeling of the human cardiovascular system using NeuralFMUs Journal of Physics: Conference Series 2090, 1, 012155. DOI: 10.1088/1742-6596/2090/1/012155","category":"page"},{"location":"faq/#FAQ","page":"FAQ","title":"FAQ","text":"","category":"section"},{"location":"faq/","page":"FAQ","title":"FAQ","text":"This list contains some common errors:","category":"page"},{"location":"faq/#ToDo","page":"FAQ","title":"ToDo","text":"","category":"section"},{"location":"examples/BouncingBall/#Create-a-Bouncing-Ball-FMU","page":"BouncingBall","title":"Create a Bouncing Ball FMU","text":"","category":"section"},{"location":"examples/BouncingBall/","page":"BouncingBall","title":"BouncingBall","text":"Tutorial by Johannes Stoljar, Tobias Thummerer","category":"page"},{"location":"examples/BouncingBall/#License","page":"BouncingBall","title":"License","text":"","category":"section"},{"location":"examples/BouncingBall/","page":"BouncingBall","title":"BouncingBall","text":"# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher, Johannes Stoljar\n# Licensed under the MIT license.\n# See LICENSE (https://github.com/thummeto/FMIExport.jl/blob/main/LICENSE) file in the project root for details.","category":"page"},{"location":"examples/BouncingBall/#Motivation","page":"BouncingBall","title":"Motivation","text":"","category":"section"},{"location":"examples/BouncingBall/","page":"BouncingBall","title":"BouncingBall","text":"This Julia Package FMIExport.jl is motivated by the export of simulation models in Julia. Here the FMI specification is implemented. FMI (Functional Mock-up Interface) is a free standard (fmi-standard.org) that defines a container and an interface to exchange dynamic models using a combination of XML files, binaries and C code zipped into a single file. The user is able to create own FMUs (Functional Mock-up Units).","category":"page"},{"location":"examples/BouncingBall/#Introduction-to-the-example","page":"BouncingBall","title":"Introduction to the example","text":"","category":"section"},{"location":"examples/BouncingBall/","page":"BouncingBall","title":"BouncingBall","text":"ToDo","category":"page"},{"location":"examples/BouncingBall/#Target-group","page":"BouncingBall","title":"Target group","text":"","category":"section"},{"location":"examples/BouncingBall/","page":"BouncingBall","title":"BouncingBall","text":"The example is primarily intended for users who work in the field of simulations. The example wants to show how simple it is to export FMUs in Julia.","category":"page"},{"location":"examples/BouncingBall/#Other-formats","page":"BouncingBall","title":"Other formats","text":"","category":"section"},{"location":"examples/BouncingBall/","page":"BouncingBall","title":"BouncingBall","text":"Besides, this Jupyter Notebook there is also a Julia file with the same name, which contains only the code cells and for the documentation there is a Markdown file corresponding to the notebook.  ","category":"page"},{"location":"examples/BouncingBall/#Getting-started","page":"BouncingBall","title":"Getting started","text":"","category":"section"},{"location":"examples/BouncingBall/#Installation-prerequisites","page":"BouncingBall","title":"Installation prerequisites","text":"","category":"section"},{"location":"examples/BouncingBall/","page":"BouncingBall","title":"BouncingBall","text":" Description Command Alternative\n1. Enter Package Manager via ] \n2. Install FMIExport via add FMIExport add \" https://github.com/ThummeTo/FMIExport.jl \"","category":"page"},{"location":"examples/BouncingBall/#Code-section","page":"BouncingBall","title":"Code section","text":"","category":"section"},{"location":"examples/BouncingBall/","page":"BouncingBall","title":"BouncingBall","text":"To run the example, the previously installed packages must be included. ","category":"page"},{"location":"examples/BouncingBall/","page":"BouncingBall","title":"BouncingBall","text":"using FMIExport ","category":"page"},{"location":"examples/BouncingBall/#Define-the-Model","page":"BouncingBall","title":"Define the Model","text":"","category":"section"},{"location":"examples/BouncingBall/","page":"BouncingBall","title":"BouncingBall","text":"In the following section the behavior of the FMU is defined by defining the functions for initialization, evaluation, output and event.","category":"page"},{"location":"examples/BouncingBall/","page":"BouncingBall","title":"BouncingBall","text":"FMU_FCT_INIT = function()\n    m = 1.0         # ball mass\n    r = 0.0         # ball radius\n    d = 0.7         # ball collision damping\n    v_min = 1e-1    # ball minimum velocity\n    g = -9.81       # gravity constant \n\n    s = 1.0         # ball position\n    v = 0.0         # ball velocity\n    a = 0.0         # ball acceleration\n\n    t = 0.0        \n    x = [s, v]      \n    ẋ = [v, a]\n    u = []\n    p = [m, r, d, v_min, g]\n\n    return (t, x, ẋ, u, p)\nend\n\nFMU_FCT_EVALUATE = function(t, x, ẋ, u, p)\n    m, r, d, v_min, g = (p...,)\n    s, v = (x...,)\n    _, a = (ẋ...,)\n\n    if s <= r && v < 0.0\n        s = r\n        v = -v*d \n        \n        # stop bouncing to prevent high frequency bouncing (and maybe tunneling the floor)\n        if v < v_min\n            v = 0.0\n            g = 0.0\n        end\n    end\n\n    a = (m * g) / m     # the system's physical equation\n\n    x = [s, v]\n    ẋ = [v, a]\n    p = [m, r, d, v_min, g]\n\n    return (x, ẋ, p)\nend\n\nFMU_FCT_OUTPUT = function(t, x, ẋ, u, p)\n    m, r, d, v_min, g = (p...,)\n    s, v = (x...,)\n    _, a = (ẋ...,)\n\n    y = [s]\n\n    return y\nend\n\nFMU_FCT_EVENT = function(t, x, ẋ, u, p)\n    m, r, d, v_min, g = (p...,)\n    s, v = (x...,)\n    _, a = (ẋ...,)\n\n    z1 = (s-r)              # event 1: ball hits ground \n   \n    if s==r && v==0.0\n        z1 = 1.0            # event 1: ball stay-on-ground\n    end\n\n    z = [z1]\n\n    return z\nend","category":"page"},{"location":"examples/BouncingBall/","page":"BouncingBall","title":"BouncingBall","text":"#7 (generic function with 1 method)","category":"page"},{"location":"examples/BouncingBall/#FMU-Constructor","page":"BouncingBall","title":"FMU Constructor","text":"","category":"section"},{"location":"examples/BouncingBall/","page":"BouncingBall","title":"BouncingBall","text":"This function is called, as soon as the DLL is loaded and Julia is initialized. The function must return a FMU2-instance to work with.","category":"page"},{"location":"examples/BouncingBall/","page":"BouncingBall","title":"BouncingBall","text":"FMIBUILD_CONSTRUCTOR = function(resPath=\".\")\n    fmu = fmi2CreateSimple(initializationFct=FMU_FCT_INIT,\n                        evaluationFct=FMU_FCT_EVALUATE,\n                        outputFct=FMU_FCT_OUTPUT,\n                        eventFct=FMU_FCT_EVENT)\n\n    # states [2]\n    fmi2AddStateAndDerivative(fmu, \"ball.s\"; stateDescr=\"Absolute position of ball center of mass\", derivativeDescr=\"Absolute velocity of ball center of mass\")\n    fmi2AddStateAndDerivative(fmu, \"ball.v\"; stateDescr=\"Absolute velocity of ball center of mass\", derivativeDescr=\"Absolute acceleration of ball center of mass\")\n\n    # outputs [1]\n    fmi2AddRealOutput(fmu, \"ball.s\"; description=\"Absolute position of ball center of mass\")\n\n    # parameters [5]\n    fmi2AddRealParameter(fmu, \"m\";     description=\"Mass of ball\")\n    fmi2AddRealParameter(fmu, \"r\";     description=\"Radius of ball\")\n    fmi2AddRealParameter(fmu, \"d\";     description=\"Collision damping constant (velocity fraction after hitting the ground)\")\n    fmi2AddRealParameter(fmu, \"v_min\"; description=\"Minimal ball velocity to enter on-ground-state\")\n    fmi2AddRealParameter(fmu, \"g\";     description=\"Gravity constant\")\n\n    fmi2AddEventIndicator(fmu)\n\n    return fmu\nend\n\n### FMIBUILD_NO_EXPORT_BEGIN ###\n# The line above is a start-marker for excluded code for the FMU compilation process!\n\ntmpDir = mktempdir(; prefix=\"fmibuildjl_test_\", cleanup=false) \n@info \"Saving example files at: $(tmpDir)\"\nfmu_save_path = joinpath(tmpDir, \"BouncingBall.fmu\")  \n\nfmu = FMIBUILD_CONSTRUCTOR()\n# using FMIBuild: fmi2Save        # <= this must be excluded during export, because FMIBuild cannot execute itself (but it is able to build)\n# fmi2Save(fmu, fmu_save_path)    # <= this must be excluded during export, because fmi2Save would start an infinte build loop with itself \n\n### some tests ###\n# using FMI\n# comp = fmiInstantiate!(fmu; loggingOn=true)\n# solution = fmiSimulateME(comp, 0.0, 10.0; dtmax=0.1)\n# fmiPlot(fmu, solution)\n# fmiFreeInstance!(comp)\n\n# The following line is a end-marker for excluded code for the FMU compilation process!\n### FMIBUILD_NO_EXPORT_END ###","category":"page"},{"location":"examples/BouncingBall/","page":"BouncingBall","title":"BouncingBall","text":"┌ Info: Saving example files at: /tmp/fmibuildjl_test_iHUSxA\n└ @ Main In[4]:30\n\n\n\n\n\nModel name:        \nType:              0","category":"page"},{"location":"examples/BouncingBall/#Summary","page":"BouncingBall","title":"Summary","text":"","category":"section"},{"location":"examples/BouncingBall/","page":"BouncingBall","title":"BouncingBall","text":"Based on this tutorial it can be seen that creating an FMU is very easy.","category":"page"}]
}
