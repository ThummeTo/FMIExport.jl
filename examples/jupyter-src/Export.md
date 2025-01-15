# Create a Bouncing Ball FMU

Tutorial by Tobias Thummerer, Simon Exner | Last edit: October 29 2024

🚧 This is a placeholder example, it will be changed or replaced soon. It is not meant to be tutorial at the current state! See the [examples folder](https://github.com/ThummeTo/FMIExport.jl/tree/main/examples/FMI2) for examples. 🚧

## License


```julia
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher, Johannes Stoljar
# Licensed under the MIT license.
# See LICENSE (https://github.com/thummeto/FMIExport.jl/blob/main/LICENSE) file in the project root for details.
```

## Motivation

This Julia Package FMIExport.jl is motivated by the export of simulation models in Julia. Here the FMI specification is implemented. FMI (Functional Mock-up Interface) is a free standard ([fmi-standard.org](https://fmi-standard.org)) that defines a container and an interface to exchange dynamic models using a combination of XML files, binaries and C code zipped into a single file. The user is able to create own FMUs (Functional Mock-up Units).

## REPL-commands or build-script

The way to do this usually will be the REPL, but if you plan on exporting FMUs in an automated way, you may want to use a jl script containing the following commands.
To run this example, the previously installed packages must be included.


```julia
using FMIExport
using FMIBuild: saveFMU
```

Next we have to define where to put the generated files:


```julia
tmpDir = mktempdir(; prefix="fmibuildjl_test_", cleanup=false) 
@info "Saving example files at: $(tmpDir)"
fmu_save_path = joinpath(tmpDir, "BouncingBall.fmu")  
```

    [36m[1m[ [22m[39m[36m[1mInfo: [22m[39mSaving example files at: C:\Users\RUNNER~1\AppData\Local\Temp\fmibuildjl_test_4aPeCb
    




    "C:\\Users\\RUNNER~1\\AppData\\Local\\Temp\\fmibuildjl_test_4aPeCb\\BouncingBall.fmu"



Remember, that we use the FMU-source stored at [examples/FMI2/BouncingBall](https://github.com/ThummeTo/FMIExport.jl/tree/main/examples/FMI2/BouncingBall). If you execute this notebook locally, make shure to adjust the fmu_source_path to where your FMU-Package resides. **It is important, that an absolute path is provided!** For this notebook to work in the automated bulid pipeline, this absolute path is obtained by the following instructions. If you run this example locally, you can provide the path manually, just make shure you use the correct directory seperator or just use just use julias `joinpath` function.


```julia
working_dir = pwd() # current working directory
println(string("pwd() returns: ", working_dir))

package_dir = split(working_dir, joinpath("examples", "jupyter-src"))[1] # remove everything after and including "examples\jupyter-src"
println(string("package_dir is ", package_dir))

fmu_source_package = joinpath(package_dir, "examples", "FMI2", "BouncingBall") # add correct relative path
println(string("fmu_source_package is ", fmu_source_package))

fmu_source_path = joinpath(fmu_source_package, "src", "BouncingBall.jl") # add correct relative path
println(string("fmu_source_path is ", fmu_source_path))
```

    pwd() returns: D:\a\FMIExport.jl\FMIExport.jl\examples\jupyter-src
    package_dir is D:\a\FMIExport.jl\FMIExport.jl\
    fmu_source_package is D:\a\FMIExport.jl\FMIExport.jl\examples\FMI2\BouncingBall
    fmu_source_path is D:\a\FMIExport.jl\FMIExport.jl\examples\FMI2\BouncingBall\src\BouncingBall.jl
    

The following codecell contains *workardound* code that will be obsolete with the next release. This is just to check the CI-Pipeline!


```julia
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
```




    Model name:	BouncingBall
    Type:		0



We need to make shure the fmu_source_package is instantiated:


```julia
using Pkg
notebook_env = Base.active_project(); # save current enviroment to return to it after we are done
Pkg.activate(fmu_source_package); # activate the FMUs enviroment

# make shure to use the same FMI source as in the enviroment of this example ("notebook_env"). 
# As this example is automattically built using the local FMIExport package and not the one from the Juila registry, we need to add it using "develop". 
Pkg.develop(PackageSpec(path=package_dir)); # If you added FMIExport using "add FMIExport", you have to remove this line and use instantiate instead.
# Pkg.instantiate(); # instantiate the FMUs enviroment only if develop was not previously called

Pkg.activate(notebook_env); # return to the original notebooks enviroment
```

    [32m[1m  Activating[22m[39m project at `D:\a\FMIExport.jl\FMIExport.jl\examples\FMI2\BouncingBall`

    
    

    [32m[1m   Resolving[22m[39m package versions...

    
    

    [32m[1m    Updating[22m[39m `D:\a\FMIExport.jl\FMIExport.jl\examples\FMI2\BouncingBall\Project.toml`
      [90m[226f0e26] [39m[92m+ FMIBuild v0.3.2[39m
      [90m[31b88311] [39m[92m+ FMIExport v0.4.1 `D:\a\FMIExport.jl\FMIExport.jl\`[39m
    [32m[1m    Updating[22m[39m `D:\a\FMIExport.jl\FMIExport.jl\examples\FMI2\BouncingBall\Manifest.toml`
    

      [90m[47edcb42] [39m[92m+ ADTypes v1.11.0[39m
      [90m[7d9f7c33] [39m[92m+ Accessors v0.1.41[39m
      [90m[79e6a3ab] [39m[92m+ Adapt v4.1.1[39m
      [90m[4fba245c] [39m[92m+ ArrayInterface v7.18.0[39m
      [90m[4c555306] [39m[92m+ ArrayLayouts v1.11.0[39m
      [90m[62783981] [39m[92m+ BitTwiddlingConvenienceFunctions v0.1.6[39m
      [90m[2a0fbf3d] [39m[92m+ CPUSummary v0.2.6[39m
    [33m⌅[39m [90m[d360d2e6] [39m[92m+ ChainRulesCore v1.24.0[39m
      [90m[fb6a15b2] [39m[92m+ CloseOpenIntervals v0.1.13[39m
      [90m[38540f10] [39m[92m+ CommonSolve v0.2.4[39m
      [90m[bbf7d656] [39m[92m+ CommonSubexpressions v0.3.1[39m
      [90m[f70d9fcc] [39m[92m+ CommonWorldInvalidations v1.0.0[39m
      [90m[34da2185] [39m[92m+ Compat v4.16.0[39m
      [90m[a33af91c] [39m[92m+ CompositionsBase v0.1.2[39m
      [90m[2569d6c7] [39m[92m+ ConcreteStructs v0.2.3[39m
      [90m[187b0558] [39m[92m+ ConstructionBase v1.5.8[39m
      [90m[adafc99b] [39m[92m+ CpuId v0.3.1[39m
      [90m[9a962f9c] [39m[92m+ DataAPI v1.16.0[39m
      [90m[864edb3b] [39m[92m+ DataStructures v0.18.20[39m
      [90m[e2d170a0] [39m[92m+ DataValueInterfaces v1.0.0[39m
      [90m[2b5f629d] [39m[92m+ DiffEqBase v6.161.0[39m
    [33m⌅[39m [90m[459566f4] [39m[92m+ DiffEqCallbacks v3.9.1[39m
      [90m[163ba53b] [39m[92m+ DiffResults v1.1.0[39m
      [90m[b552c78f] [39m[92m+ DiffRules v1.15.1[39m
      [90m[a0c0ee7d] [39m[92m+ DifferentiationInterface v0.6.29[39m
      [90m[ffbed154] [39m[92m+ DocStringExtensions v0.9.3[39m
      [90m[4e289a0a] [39m[92m+ EnumX v1.0.4[39m
      [90m[f151be2c] [39m[92m+ EnzymeCore v0.8.8[39m
      [90m[e2ba6199] [39m[92m+ ExprTools v0.1.10[39m
    [33m⌅[39m [90m[6b7a57c9] [39m[92m+ Expronicon v0.8.5[39m
      [90m[8f5d6c58] [39m[92m+ EzXML v1.2.0[39m
      [90m[900ee838] [39m[92m+ FMIBase v1.0.10[39m
      [90m[226f0e26] [39m[92m+ FMIBuild v0.3.2[39m
      [90m[8af89139] [39m[92m+ FMICore v1.1.1[39m
      [90m[31b88311] [39m[92m+ FMIExport v0.4.1 `D:\a\FMIExport.jl\FMIExport.jl\`[39m
      [90m[7034ab61] [39m[92m+ FastBroadcast v0.3.5[39m
      [90m[9aa1b823] [39m[92m+ FastClosures v0.3.2[39m
      [90m[29a986be] [39m[92m+ FastLapackInterface v2.0.4[39m
      [90m[a4df4552] [39m[92m+ FastPower v1.1.1[39m
      [90m[1a297f60] [39m[92m+ FillArrays v1.13.0[39m
      [90m[6a86dc24] [39m[92m+ FiniteDiff v2.26.2[39m
      [90m[f6369f11] [39m[92m+ ForwardDiff v0.10.38[39m
      [90m[069b7b12] [39m[92m+ FunctionWrappers v1.1.3[39m
      [90m[77dc65aa] [39m[92m+ FunctionWrappersWrappers v0.1.3[39m
    [33m⌅[39m [90m[d9f16b24] [39m[92m+ Functors v0.4.12[39m
      [90m[46192b85] [39m[92m+ GPUArraysCore v0.2.0[39m
      [90m[c27321d9] [39m[92m+ Glob v1.3.1[39m
      [90m[3e5b6fbb] [39m[92m+ HostCPUFeatures v0.1.17[39m
      [90m[615f187c] [39m[92m+ IfElse v0.1.1[39m
      [90m[3587e190] [39m[92m+ InverseFunctions v0.1.17[39m
      [90m[92d709cd] [39m[92m+ IrrationalConstants v0.2.2[39m
      [90m[82899510] [39m[92m+ IteratorInterfaceExtensions v1.0.0[39m
      [90m[692b3bcd] [39m[92m+ JLLWrappers v1.7.0[39m
      [90m[ef3ab10e] [39m[92m+ KLU v0.6.0[39m
      [90m[ba0b0d4f] [39m[92m+ Krylov v0.9.8[39m
      [90m[10f19ff3] [39m[92m+ LayoutPointers v0.1.17[39m
      [90m[5078a376] [39m[92m+ LazyArrays v2.3.2[39m
      [90m[87fe0de2] [39m[92m+ LineSearch v0.1.4[39m
      [90m[d3d80556] [39m[92m+ LineSearches v7.3.0[39m
      [90m[7ed4a6bd] [39m[92m+ LinearSolve v2.38.0[39m
      [90m[2ab3a3ac] [39m[92m+ LogExpFunctions v0.3.29[39m
      [90m[bdcacae8] [39m[92m+ LoopVectorization v0.12.171[39m
      [90m[d8e11817] [39m[92m+ MLStyle v0.4.17[39m
      [90m[1914dd2f] [39m[92m+ MacroTools v0.5.15[39m
      [90m[d125e4d3] [39m[92m+ ManualMemory v0.1.8[39m
      [90m[bb5d69b7] [39m[92m+ MaybeInplace v0.1.4[39m
      [90m[46d2c3a1] [39m[92m+ MuladdMacro v0.2.4[39m
      [90m[d41bc354] [39m[92m+ NLSolversBase v7.8.3[39m
      [90m[77ba4419] [39m[92m+ NaNMath v1.0.3[39m
    [33m⌅[39m [90m[8913a72c] [39m[92m+ NonlinearSolve v3.15.1[39m
      [90m[6fe1bfb0] [39m[92m+ OffsetArrays v1.15.0[39m
      [90m[bac558e1] [39m[92m+ OrderedCollections v1.7.0[39m
      [90m[9b87118b] [39m[92m+ PackageCompiler v2.2.0[39m
      [90m[65ce6f38] [39m[92m+ PackageExtensionCompat v1.0.2[39m
      [90m[d96e819e] [39m[92m+ Parameters v0.12.3[39m
      [90m[f517fe37] [39m[92m+ Polyester v0.7.16[39m
      [90m[1d0040c9] [39m[92m+ PolyesterWeave v0.2.2[39m
      [90m[d236fae5] [39m[92m+ PreallocationTools v0.4.24[39m
      [90m[aea7be01] [39m[92m+ PrecompileTools v1.2.1[39m
      [90m[21216c6a] [39m[92m+ Preferences v1.4.3[39m
      [90m[92933f4c] [39m[92m+ ProgressMeter v1.10.2[39m
      [90m[3cdcf5f2] [39m[92m+ RecipesBase v1.3.4[39m
      [90m[731186ca] [39m[92m+ RecursiveArrayTools v3.27.4[39m
      [90m[f2c3362d] [39m[92m+ RecursiveFactorization v0.2.23[39m
      [90m[189a3867] [39m[92m+ Reexport v1.2.2[39m
      [90m[05181044] [39m[92m+ RelocatableFolders v1.0.1[39m
      [90m[ae029012] [39m[92m+ Requires v1.3.0[39m
      [90m[7e49a35a] [39m[92m+ RuntimeGeneratedFunctions v0.5.13[39m
      [90m[94e857df] [39m[92m+ SIMDTypes v0.1.0[39m
      [90m[476501e8] [39m[92m+ SLEEFPirates v0.6.43[39m
      [90m[0bca4576] [39m[92m+ SciMLBase v2.70.0[39m
      [90m[19f34311] [39m[92m+ SciMLJacobianOperators v0.1.1[39m
      [90m[c0aeaf25] [39m[92m+ SciMLOperators v0.3.12[39m
      [90m[53ae85a6] [39m[92m+ SciMLStructures v1.6.1[39m
      [90m[6c6a2e73] [39m[92m+ Scratch v1.2.1[39m
      [90m[efcf1570] [39m[92m+ Setfield v1.1.1[39m
    [33m⌅[39m [90m[727e6d20] [39m[92m+ SimpleNonlinearSolve v1.12.3[39m
      [90m[9f842d2f] [39m[92m+ SparseConnectivityTracer v0.6.9[39m
      [90m[0a514795] [39m[92m+ SparseMatrixColorings v0.4.10[39m
      [90m[e56a9233] [39m[92m+ Sparspak v0.3.9[39m
      [90m[276daf66] [39m[92m+ SpecialFunctions v2.5.0[39m
      [90m[aedffcd0] [39m[92m+ Static v1.1.1[39m
      [90m[0d7ed370] [39m[92m+ StaticArrayInterface v1.8.0[39m
      [90m[1e83bf80] [39m[92m+ StaticArraysCore v1.4.3[39m
      [90m[7792a7ef] [39m[92m+ StrideArraysCore v0.5.7[39m
      [90m[2efcf032] [39m[92m+ SymbolicIndexingInterface v0.3.37[39m
      [90m[3783bdb8] [39m[92m+ TableTraits v1.0.1[39m
      [90m[bd369af6] [39m[92m+ Tables v1.12.0[39m
      [90m[8290d209] [39m[92m+ ThreadingUtilities v0.5.2[39m
      [90m[a759f4b9] [39m[92m+ TimerOutputs v0.5.26[39m
      [90m[d5829a12] [39m[92m+ TriangularSolve v0.2.1[39m
      [90m[781d530d] [39m[92m+ TruncatedStacktraces v1.4.0[39m
      [90m[3a884ed6] [39m[92m+ UnPack v1.0.2[39m
      [90m[3d5dd08c] [39m[92m+ VectorizationBase v0.21.71[39m
      [90m[a5390f91] [39m[92m+ ZipFile v0.10.1[39m
      [90m[1d5cc7b8] [39m[92m+ IntelOpenMP_jll v2024.2.1+0[39m
      [90m[94ce4f54] [39m[92m+ Libiconv_jll v1.18.0+0[39m
      [90m[856f044c] [39m[92m+ MKL_jll v2024.2.0+0[39m
      [90m[efe28fd5] [39m[92m+ OpenSpecFun_jll v0.5.6+0[39m
      [90m[02c8fc9c] [39m[92m+ XML2_jll v2.13.5+0[39m
      [90m[1317d2d5] [39m[92m+ oneTBB_jll v2021.12.0+0[39m
      [90m[0dad84c5] [39m[92m+ ArgTools v1.1.1[39m
      [90m[56f22d72] [39m[92m+ Artifacts[39m
      [90m[2a0f44e3] [39m[92m+ Base64[39m
      [90m[ade2ca70] [39m[92m+ Dates[39m
      [90m[8ba89e20] [39m[92m+ Distributed[39m
      [90m[f43a241f] [39m[92m+ Downloads v1.6.0[39m
      [90m[7b1f6079] [39m[92m+ FileWatching[39m
      [90m[9fa8497b] [39m[92m+ Future[39m
      [90m[b77e0a4c] [39m[92m+ InteractiveUtils[39m
      [90m[4af54fe1] [39m[92m+ LazyArtifacts[39m
      [90m[b27032c2] [39m[92m+ LibCURL v0.6.4[39m
      [90m[76f85450] [39m[92m+ LibGit2[39m
      [90m[8f399da3] [39m[92m+ Libdl[39m
      [90m[37e2e46d] [39m[92m+ LinearAlgebra[39m
      [90m[56ddb016] [39m[92m+ Logging[39m
      [90m[d6f4376e] [39m[92m+ Markdown[39m
      [90m[ca575930] [39m[92m+ NetworkOptions v1.2.0[39m
      [90m[44cfe95a] [39m[92m+ Pkg v1.10.0[39m
      [90m[de0858da] [39m[92m+ Printf[39m
      [90m[3fa0cd96] [39m[92m+ REPL[39m
      [90m[9a3f8284] [39m[92m+ Random[39m
      [90m[ea8e919c] [39m[92m+ SHA v0.7.0[39m
      [90m[9e88b42a] [39m[92m+ Serialization[39m
      [90m[6462fe0b] [39m[92m+ Sockets[39m
      [90m[2f01184e] [39m[92m+ SparseArrays v1.10.0[39m
      [90m[10745b16] [39m[92m+ Statistics v1.10.0[39m
      [90m[fa267f1f] [39m[92m+ TOML v1.0.3[39m
      [90m[a4e569a6] [39m[92m+ Tar v1.10.0[39m
      [90m[8dfed614] [39m[92m+ Test[39m
      [90m[cf7118a7] [39m[92m+ UUIDs[39m
      [90m[4ec0a83e] [39m[92m+ Unicode[39m
      [90m[e66e0078] [39m[92m+ CompilerSupportLibraries_jll v1.1.1+0[39m
      [90m[deac9b47] [39m[92m+ LibCURL_jll v8.4.0+0[39m
      [90m[e37daf67] [39m[92m+ LibGit2_jll v1.6.4+0[39m
      [90m[29816b5a] [39m[92m+ LibSSH2_jll v1.11.0+1[39m
      [90m[c8ffd9c3] [39m[92m+ MbedTLS_jll v2.28.2+1[39m
      [90m[14a3606d] [39m[92m+ MozillaCACerts_jll v2023.1.10[39m
      [90m[4536629a] [39m[92m+ OpenBLAS_jll v0.3.23+4[39m
      [90m[05823500] [39m[92m+ OpenLibm_jll v0.8.1+2[39m
      [90m[bea87d4a] [39m[92m+ SuiteSparse_jll v7.2.1+1[39m
      [90m[83775a58] [39m[92m+ Zlib_jll v1.2.13+1[39m
      [90m[8e850b90] [39m[92m+ libblastrampoline_jll v5.11.0+0[39m
      [90m[8e850ede] [39m[92m+ nghttp2_jll v1.52.0+1[39m
      [90m[3f19e933] [39m[92m+ p7zip_jll v17.4.0+2[39m
    [36m[1m        Info[22m[39m Packages marked with [33m⌅[39m have new versions available but compatibility constraints restrict them from upgrading. To see why use `status --outdated -m`
    [32m[1m  Activating[22m[39m project at `D:\a\FMIExport.jl\FMIExport.jl\examples`
    

That is all the preperation, that was necessary. Now we can export the FMU. 

The following codecell contains *workardound* code that will need to be modified with the next release.


```julia
# currently export is broken, therefor we will not do it
#saveFMU(fmu, fmu_save_path, fmu_source_path; debug=false, compress=false) # feel free to set debug true, disabled for documentation building
#saveFMU(fmu_save_path, fmu_source_path; debug=false, compress=false) this meight be the format after the next release
```

Now we will grab the generated FMU and move it to a path, where it will be included in this documentation


```julia
mkpath("Export_files")
# currently export is broken, therefor we will not find anything there
#cp(fmu_save_path, joinpath("Export_files", "BouncingBall.fmu"))
```




    "Export_files"



One current limitation of Julia-FMUs is, that they can not be imported back into Julia, as it is currently not allowed having two Julia-sys-images existing at the same time within the same process. (The Julia FMU comes bundeled with its own image).

Therefore we will test our generated FMU in Python unsing FMPy.
