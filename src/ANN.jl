#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

abstract type Layer end

### Dense ###

struct Dense{T} <: Layer
    W::AbstractMatrix{T}
    b::AbstractArray{T}
    σ::Any

    function Dense{T}(W::AbstractMatrix{T}, b::AbstractArray{T}, σ) where {T<:Real}
        inst = new(W, b, σ)
        return inst
    end

    function Dense{T}(in::Integer, out::Integer, σ) where {T}
        W = zeros(T, out, in)
        b = zeros(T, out)
        return Dense{T}(W, b, σ)
    end
end

function (l::Dense)(x)

    return l.σ.(l.W * x + l.b)
end

### Chain ###

struct Chain <: Layer
    layers::AbstractArray

    function Chain(layers...)
        return new([layers...])
    end
end

function (l::Chain)(x)
    for layer in l.layers
        x = layer(x)
    end
    return x
end

import Base.getindex
function getindex(l::Chain, keys...)
    getindex(l.layers, keys...)
end

import Base.length
function length(l::Chain)
    length(l.layers)
end
