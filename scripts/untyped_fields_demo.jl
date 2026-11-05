# untyped_fields_demo.jl
#
# Demonstrates the practical consequences of untyped struct fields in Julia.
# Run from the repository root with:
#
#     julia --project=. scripts/untyped_fields_demo.jl
#
# Tested with Julia 1.12.7. Numbers are machine-dependent; the ratios are the
# point, not the absolute milliseconds.

using InteractiveUtils

# ---------------------------------------------------------------------------
# Four ways to declare the same single field
# ---------------------------------------------------------------------------
struct Loose
    x            # x::Any
end

struct Tight
    x::Float64
end

struct Param{T}
    x::T
end

struct RealBox
    x::Real     # abstract annotation: "typed" but not concrete
end

# A @noinline accessor: compiled against ::Loose/::Tight alone, so inference
# only has the *declared* field type to work with.
@noinline getx(s) = s.x

println("="^70)
println("Declared field types and inferred accessor return types")
println("="^70)
for T in (Loose, Tight, RealBox, Param{Float64}, Param{Any})
    rt = only(Base.return_types(getx, (T,)))
    println(rpad(string(T), 18), " fieldtypes = ", fieldtypes(T),
            "  ->  getx :: ", rt)
end
println()
println("isbitstype(Loose)    = ", isbitstype(Loose))
println("isbitstype(Tight)    = ", isbitstype(Tight))
println("isbitstype(RealBox)  = ", isbitstype(RealBox))
println("sizeof(Loose(1.0))   = ", sizeof(Loose(1.0)), "  (a pointer)")
println("sizeof(Tight(1.0))   = ", sizeof(Tight(1.0)), "  (the Float64 itself)")

# ---------------------------------------------------------------------------
# Hot-loop benchmark: field access through a concrete container
# ---------------------------------------------------------------------------
@noinline function total(v)
    s = 0.0
    @inbounds for i in eachindex(v)
        s += v[i].x
    end
    return s
end

function best_time(f, v; reps = 5)
    f(v)                       # compile + warm up
    t = Inf
    for _ in 1:reps
        t = min(t, @elapsed f(v))
    end
    return t
end

const N = 10_000_000

loose = [Loose(float(i)) for i in 1:N]
tight = [Tight(float(i)) for i in 1:N]
realb = [RealBox(float(i)) for i in 1:N]
param = [Param(float(i)) for i in 1:N]

results = [
    ("Vector{Loose}   (x::Any)     ", loose),
    ("Vector{RealBox} (x::Real)    ", realb),
    ("Vector{Tight}   (x::Float64) ", tight),
    ("Vector{Param{Float64}} (x::T)", param),
]

println()
println("="^70)
println("Hot loop: s += v[i].x over ", N, " elements (best of 5)")
println("="^70)
for (name, v) in results
    t = best_time(total, v)
    total(v)                   # warm up for the allocation measurement
    a = @allocated total(v)
    println(rpad(name, 36), lpad(round(t * 1e3, digits = 2), 8), " ms   ",
            lpad(a, 12), " bytes")
end

# Correctness: all four should compute the same sum.
s_loose = total(loose)
s_tight = total(tight)
s_realb = total(realb)
s_param = total(param)
println()
println("sums equal: ",
        s_loose == s_tight == s_realb == s_param,
        "   (", s_loose, ")")

# ---------------------------------------------------------------------------
# Abstract element type: Vector{Param} vs Vector{Param{Float64}}
# ---------------------------------------------------------------------------
# Param itself is a UnionAll, so `Vector{Param}` has an abstract element type
# even when every element happens to be a Param{Float64}. This is the case the
# flexibility note warns about; it is *not* what the row above measures.
const NA = 2_000_000
abstract_params = Param[Param(float(i)) for i in 1:NA]
concrete_params = Param{Float64}[Param(float(i)) for i in 1:NA]

println()
println("="^70)
println("Same values, abstract vs concrete container eltype (", NA, " elements)")
println("="^70)
println("eltype(abstract_params) = ", eltype(abstract_params))
println("eltype(concrete_params) = ", eltype(concrete_params))
println("inferred total(::Vector{Param})          = ",
        only(Base.return_types(total, (Vector{Param},))))
println("inferred total(::Vector{Param{Float64}}) = ",
        only(Base.return_types(total, (Vector{Param{Float64}},))))
for (name, v) in (("Vector{Param} (abstract eltype)", abstract_params),
                  ("Vector{Param{Float64}}         ", concrete_params))
    t = best_time(total, v)
    total(v)
    println(rpad(name, 34), lpad(round(t * 1e3, digits = 2), 8), " ms   ",
            lpad(@allocated(total(v)), 12), " bytes")
end

# ---------------------------------------------------------------------------
# Array construction cost: pointer-per-element vs inline storage
# ---------------------------------------------------------------------------
println()
println("="^70)
println("Construction cost of a 1M-element vector")
println("="^70)
const M = 1_000_000
[Loose(float(i)) for i in 1:10]     # compile
[Tight(float(i)) for i in 1:10]
println("Vector{Loose}: ", @allocated([Loose(float(i)) for i in 1:M]), " bytes")
println("Vector{Tight}: ", @allocated([Tight(float(i)) for i in 1:M]), " bytes")

# ---------------------------------------------------------------------------
# The case where the compiler still optimizes the untyped field
# ---------------------------------------------------------------------------
# Constructed and consumed locally; the object never escapes, so inference
# can represent it as Core.PartialStruct(Loose, Any[Float64]).
@noinline function local_total(v)
    s = 0.0
    @inbounds for i in eachindex(v)
        b = Loose(v[i])
        s += b.x
    end
    return s
end

v = rand(10^7)
local_total(v)                       # warm up
println()
println("="^70)
println("Non-escaping local construction with the untyped field")
println("="^70)
println("inferred return type: ",
        only(Base.return_types(local_total, (Vector{Float64},))))
println("time:         ", round(best_time(local_total, v) * 1e3, digits = 2), " ms")
println("allocations:  ", @allocated(local_total(v)), " bytes")
println()
println("Compare with the raw-Float64 loop over the same data:")
@noinline raw_total(v) = (s = 0.0; @inbounds for x in v; s += x; end; s)
raw_total(v)
println("raw time:     ", round(best_time(raw_total, v) * 1e3, digits = 2), " ms")
println("raw allocations: ", @allocated(raw_total(v)), " bytes")

# ---------------------------------------------------------------------------
# Flexibility: parametric fields keep each instance concrete
# ---------------------------------------------------------------------------
println()
println("="^70)
println("Flexibility")
println("="^70)
p = Param[Param(1), Param(2.5), Param("three")]
println("eltype(p) = ", eltype(p), ", concrete element types = ", typeof.(p))
println("A Vector{Param} has an abstract eltype. A hot loop over it is")
println("dynamically dispatched even if every element is a Param{Float64};")
println("see the measured 'abstract vs concrete container eltype' section above.")
println("Use Vector{Param{Float64}} or a function barrier when it matters.")

loose_mixed = Loose[Loose(1), Loose(2.5), Loose("three")]
println("Vector{Loose} field types:   ", typeof.(getfield.(loose_mixed, :x)))

println()
println("Done.")
