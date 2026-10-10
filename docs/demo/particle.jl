# Two of the mistakes the lint rules catch, for the demo recording.
struct Particle
    pos
    vel::AbstractVector
end

move(p::Particle, dt::Real) = Particle(p.pos .+ dt .* p.vel, p.vel)
move(p::Particle, dt::T) where {T <: Real} = Particle(p.pos .+ dt .* p.vel, p.vel)
