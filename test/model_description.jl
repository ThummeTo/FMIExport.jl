#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

# ToDo: This is not a good test... 

md = fmi2CreateModelDescription()
fmi2ModelDescriptionAddRealStateAndDerivative(md, "mass.s")
fmi2ModelDescriptionAddRealStateAndDerivative(md, "mass.v")
fmi2ModelDescriptionAddRealOutput(md, "mass.f")