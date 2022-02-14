# FMIExport.jl

## What is FMIExport.jl?
FMIExport.jl is a free-to-use software library for the Julia programming language which allows for the export of FMUs ([fmi-standard.org](http://fmi-standard.org/)) from any Julia-Code. FMIExport.jl is completely integrated into [FMI.jl](https://github.com/ThummeTo/FMI.jl).

[![](https://github.com/ThummeTo/FMIExport.jl/actions/workflows/Test.yml/badge.svg)]() 

## How can I use FMIExport.jl?
1. open a Julia-Command-Window, activate your prefered environment
1. goto package manager using ```]```
1. type ```add https://github.com/JuliaLang/PackageCompiler.jl#kms/fix-windows-library-filename``` (there is currently an issue with the release v2.0.4 of PackageCompiler that will be fixed soon)
1. type ```add FMIExport```

## What FMI.jl-Library should I use?
![FMI.jl Family](https://github.com/ThummeTo/FMI.jl/blob/main/docs/src/assets/FMI_JL_family.png "FMI.jl Family")
To keep dependencies nice and clean, the original package *FMI.jl* had been split into new packages:
- [*FMI.jl*](https://github.com/ThummeTo/FMI.jl): High level loading, manipulating, saving or building entire FMUs from scratch
- [*FMIImport.jl*](https://github.com/ThummeTo/FMIImport.jl): Importing FMUs into Julia
- [*FMIExport.jl*](https://github.com/ThummeTo/FMIExport.jl): Exporting stand-alone FMUs from Julia Code
- [*FMICore.jl*](https://github.com/ThummeTo/FMICore.jl): C-code wrapper for the FMI-standard
- [*FMIBuild.jl*](https://github.com/ThummeTo/FMIBuild.jl): Compiler/Compilation dependencies for FMIExport.jl
- [*FMIFlux.jl*](https://github.com/ThummeTo/FMIFlux.jl): Machine Learning with FMUs (differentiation over FMUs)

## What Platforms are supported?
*FMIExport.jl* is tested (and testing) under Julia Versions *1.6.5 LTS* and *latest* on Windows *latest* and Ubuntu *latest*. `x64` architectures are tested. Mac and x86-architectures might work, but are not tested.

## How to cite?
Tobias Thummerer, Lars Mikelsons and Josef Kircher. 2021. **NeuralFMU: towards structural integration of FMUs into neural networks.** Martin Sjölund, Lena Buffoni, Adrian Pop and Lennart Ochel (Ed.). Proceedings of 14th Modelica Conference 2021, Linköping, Sweden, September 20-24, 2021. Linköping University Electronic Press, Linköping (Linköping Electronic Conference Proceedings ; 181), 297-306. [DOI: 10.3384/ecp21181297](https://doi.org/10.3384/ecp21181297)

## Related publications
Tobias Thummerer, Johannes Tintenherr, Lars Mikelsons 2021 **Hybrid modeling of the human cardiovascular system using NeuralFMUs** Journal of Physics: Conference Series 2090, 1, 012155. [DOI: 10.1088/1742-6596/2090/1/012155](https://doi.org/10.1088/1742-6596/2090/1/012155)
