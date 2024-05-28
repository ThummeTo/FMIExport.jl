![FMI.jl Logo](https://github.com/ThummeTo/FMI.jl/blob/main/logo/dark/fmijl_logo_640_320.png?raw=true "FMI.jl Logo")
# FMIExport.jl

## What is FMIExport.jl?
[*FMIExport.jl*](https://github.com/ThummeTo/FMIExport.jl) is a free-to-use software library for the Julia programming language which allows for the export of FMUs ([fmi-standard.org](http://fmi-standard.org/)) from any Julia-Code. [*FMIExport.jl*](https://github.com/ThummeTo/FMIExport.jl) is completely integrated into [*FMI.jl*](https://github.com/ThummeTo/FMI.jl).

[![Dev Docs](https://img.shields.io/badge/docs-dev-blue.svg)](https://ThummeTo.github.io/FMIExport.jl/dev) 
[![Test (latest)](https://github.com/ThummeTo/FMIExport.jl/actions/workflows/TestLatest.yml/badge.svg)](https://github.com/ThummeTo/FMIExport.jl/actions/workflows/TestLatest.yml)
[![Test (LTS)](https://github.com/ThummeTo/FMIExport.jl/actions/workflows/TestLTS.yml/badge.svg)](https://github.com/ThummeTo/FMIExport.jl/actions/workflows/TestLTS.yml)
[![Run Examples](https://github.com/ThummeTo/FMIExport.jl/actions/workflows/Example.yml/badge.svg)](https://github.com/ThummeTo/FMIExport.jl/actions/workflows/Example.yml)
[![Build Docs](https://github.com/ThummeTo/FMIExport.jl/actions/workflows/Documentation.yml/badge.svg)](https://github.com/ThummeTo/FMIExport.jl/actions/workflows/Documentation.yml)
[![Run PkgEval](https://github.com/ThummeTo/FMIExport.jl/actions/workflows/Eval.yml/badge.svg)](https://github.com/ThummeTo/FMIExport.jl/actions/workflows/Eval.yml)
[![Coverage](https://codecov.io/gh/ThummeTo/FMIExport.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/ThummeTo/FMIExport.jl)
[![ColPrac: Contributor's Guide on Collaborative Practices for Community Packages](https://img.shields.io/badge/ColPrac-Contributor's%20Guide-blueviolet)](https://github.com/SciML/ColPrac)

## How can I use FMIExport.jl?

1\. Open a Julia-REPL, switch to package mode using `]`, activate your preferred environment.

2\. Install [*FMIExport.jl*](https://github.com/ThummeTo/FMIExport.jl):
```julia-repl
(@v1) pkg> add FMIExport
```

3\. If you want to check that everything works correctly, you can run the tests bundled with [*FMIExport.jl*](https://github.com/ThummeTo/FMIExport.jl):
```julia-repl
(@v1) pkg> test FMIExport
```

4\. Have a look inside the [examples folder](https://github.com/ThummeTo/FMIExport.jl/tree/main/examples/FMI2).

## What FMI.jl-Library should I use?
![FMI.jl Logo](https://github.com/ThummeTo/FMI.jl/blob/main/docs/src/assets/FMI_JL_family.png?raw=true "FMI.jl Family")
To keep dependencies nice and clean, the original package [*FMI.jl*](https://github.com/ThummeTo/FMI.jl) had been split into new packages:
- [*FMI.jl*](https://github.com/ThummeTo/FMI.jl): High level loading, manipulating, saving or building entire FMUs from scratch
- [*FMIImport.jl*](https://github.com/ThummeTo/FMIImport.jl): Importing FMUs into Julia
- [*FMIExport.jl*](https://github.com/ThummeTo/FMIExport.jl): Exporting stand-alone FMUs from Julia Code
- [*FMIBase.jl*](https://github.com/ThummeTo/FMIBase.jl): Common concepts for import and export of FMUs
- [*FMICore.jl*](https://github.com/ThummeTo/FMICore.jl): C-code wrapper for the FMI-standard
- [*FMISensitivity.jl*](https://github.com/ThummeTo/FMISensitivity.jl): Static and dynamic sensitivities over FMUs
- [*FMIBuild.jl*](https://github.com/ThummeTo/FMIBuild.jl): Compiler/Compilation dependencies for FMIExport.jl
- [*FMIFlux.jl*](https://github.com/ThummeTo/FMIFlux.jl): Machine Learning with FMUs
- [*FMIZoo.jl*](https://github.com/ThummeTo/FMIZoo.jl): A collection of testing and example FMUs

## What Platforms are supported?
[*FMIExport.jl*](https://github.com/ThummeTo/FMIExport.jl) is tested (and testing) under Julia *v1.6 (LTS)* and *v1 (latest)* on Windows *latest*. `x64` architectures are tested. Ubuntu is under development and near completion.

## Known limitations
- Currently it is not possible to hold more than one sysimg in a Julia session, so it is not possible to load FMUs generated with [*FMIExport.jl*](https://github.com/ThummeTo/FMIExport.jl) into [*FMI.jl*](https://github.com/ThummeTo/FMI.jl) using `fmiLoad(...)`. However, FMUs created with `fmiCreate` can be used in [*FMI.jl*](https://github.com/ThummeTo/FMI.jl) without the need to export and re-import it, the FMU behaves like any other FMU loaded via `fmiLoad`.

## How to cite?
Tobias Thummerer, Johannes Stoljar and Lars Mikelsons. 2022. **NeuralFMU: presenting a workflow for integrating hybrid NeuralODEs into real-world applications.** Electronics 11, 19, 3202. [DOI: 10.3390/electronics11193202](https://doi.org/10.3390/electronics11193202)

## Related publications?
Tobias Thummerer, Lars Mikelsons and Josef Kircher. 2021. **NeuralFMU: towards structural integration of FMUs into neural networks.** Martin Sjölund, Lena Buffoni, Adrian Pop and Lennart Ochel (Ed.). Proceedings of 14th Modelica Conference 2021, Linköping, Sweden, September 20-24, 2021. Linköping University Electronic Press, Linköping (Linköping Electronic Conference Proceedings ; 181), 297-306. [DOI: 10.3384/ecp21181297](https://doi.org/10.3384/ecp21181297)

Tobias Thummerer, Johannes Tintenherr, Lars Mikelsons. 2021 **Hybrid modeling of the human cardiovascular system using NeuralFMUs** Journal of Physics: Conference Series 2090, 1, 012155. [DOI: 10.1088/1742-6596/2090/1/012155](https://doi.org/10.1088/1742-6596/2090/1/012155)
