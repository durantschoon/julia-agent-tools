# particles_2d.jl
#
# Minimal 2D particle module + example.
#
# This file is the clean reference of the struct-field probe
# (docs/model-probes.md): check.sh must report no hits here.
#
# Run with (from the repository root):
#     julia --project=. docs/probes/struct-fields/particles_2d.jl

module Particles2D

export Particle, advance, advance_all!

"""
    Particle{T <: Real}

A 2D particle with position `(x, y)` and velocity `(vx, vy)`.
All four fields share the same concrete numeric type `T`.
"""
struct Particle{T <: Real}
    x::T
    y::T
    vx::T
    vy::T
end

"""
    advance(p::Particle{T}, dt) -> Particle{T}

Return a new particle whose position is advanced by `dt`.
Velocity is unchanged (this minimal model has no forces).
"""
@inline function advance(p::Particle{T}, dt::Real) where {T}
    return Particle{T}(p.x + p.vx * dt,
                       p.y + p.vy * dt,
                       p.vx,
                       p.vy)
end

"""
    advance_all!(particles, dt, steps = 10) -> particles

Advance every particle in `particles` in place for `steps` steps of size `dt`.
"""
function advance_all!(particles::AbstractVector{<:Particle},
                      dt::Real,
                      steps::Integer = 10)
    for _ in 1:steps
        @inbounds for i in eachindex(particles)
            particles[i] = advance(particles[i], dt)
        end
    end
    return particles
end

function main()
    n = 1_000
    dt = 0.1
    steps = 10

    # Position i, moving diagonally; after 10 steps:
    #   x = i + 1.0 * 0.1 * 10 = i + 1
    #   y = 0 + 0.5 * 0.1 * 10 = 0.5
    particles = [Particle(Float64(i), 0.0, 1.0, 0.5) for i in 1:n]

    advance_all!(particles, dt, steps)

    @assert particles[1].x ≈ 2.0
    @assert particles[1].y ≈ 0.5
    @assert particles[end].x ≈ n + 1.0

    println("Updated $n particles for $steps steps (dt = $dt).")
    println("First: ", particles[1])
    println("Last:  ", particles[end])
end

end # module

Particles2D.main()
