# Two of the mistakes the lint rules catch, plus one parametric method for the
# structural-search scene. Used by docs/demo.tape.
struct Particle
    pos
    vel::AbstractVector
end

speed(v::AbstractVector{T}) where {T <: Real} = sqrt(sum(abs2, v))
