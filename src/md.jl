#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

# smallest value reference (starting at `first`) that is not used by any model variable,
# unlike `maximum + 1`, this does not overflow if an (embedded) FMU uses the largest value reference
function nextValueReference(md::fmiModelDescription, first)
    used = Set(var.valueReference for var in md.modelVariables)
    vr = first
    while vr ∈ used
        vr = Base.checked_add(vr, one(vr))
    end
    return vr
end
