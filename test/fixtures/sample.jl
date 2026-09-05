module SampleModule

export AbstractShape, Circle, MutablePoint, Color, Point3D, area, move!

abstract type AbstractShape{T <: Real} end

struct Circle{T <: Real} <: AbstractShape{T}
    radius::T
end

mutable struct MutablePoint{T <: Real}
    x::T
    y::T
end

@enum Color RED GREEN BLUE

const Point3D = MutablePoint{Float64}
const MAX_RADIUS = 1000.0

@inline area(c::Circle{T}) where {T} = T(pi) * c.radius^2

function move!(p::MutablePoint{T}, dx::T, dy::T) where {T}
    p.x += dx
    p.y += dy
    return p
end

macro log_call(ex)
    quote
        println("Calling expression")
        $(esc(ex))
    end
end

end # module SampleModule
