# field_checks_demo.jl
#
# A small type set + hot loop used to exercise this repo's two struct-field
# rules. The "Bad" declarations are intentional: they are the lint input.
#
# This file is the flagged control of the struct-field probe
# (docs/model-probes.md): check.sh must report exactly two hits here.
#
# Run the demo (from the repository root):
#     julia --project=. docs/probes/struct-fields/field_checks_demo.jl
#
# Run the two field checks on it:
#     docs/probes/struct-fields/check.sh docs/probes/struct-fields/field_checks_demo.jl
#
# Or run every project rule through the CLI (noisier):
#     ./bin/julia-agent-tools scan docs/probes/struct-fields/field_checks_demo.jl

# --- intentionally flagged by lint-untyped-struct-field --------------------
struct UntypedBox
    x                    # no annotation -> x::Any
    n::Int
end

# --- intentionally flagged by lint-abstract-struct-field -------------------
struct AbstractBox
    x::Real              # abstract annotation, still pointer-boxed
    n::Int
end

# --- clean controls --------------------------------------------------------
struct TypedBox
    x::Float64
    n::Int
end

struct ParamBox{T <: Real}
    x::T
    n::Int
end

# One generic hot loop; Julia specializes it for each element type.
@noinline function sum_x(v)
    s = 0.0
    @inbounds for i in eachindex(v)
        s += v[i].x
    end
    return s
end

function best_time(f, v; reps = 5)
    f(v)                          # compile + warm up
    t = Inf
    for _ in 1:reps
        t = min(t, @elapsed f(v))
    end
    return t
end

const N = 2_000_000

function main()
    boxes = [
        ("UntypedBox   (x::Any)    ", [UntypedBox(float(i), i) for i in 1:N]),
        ("AbstractBox  (x::Real)   ", [AbstractBox(float(i), i) for i in 1:N]),
        ("TypedBox     (x::Float64)", [TypedBox(float(i), i) for i in 1:N]),
        ("ParamBox{Float64} (x::T) ", [ParamBox(float(i), i) for i in 1:N]),
    ]

    println("="^78)
    println("Generated fields and inferred hot-loop return types")
    println("="^78)
    for (name, v) in boxes
        T = eltype(v)
        println(rpad(name, 27),
                " fieldtypes=", fieldtypes(T),
                "  isbits=", isbitstype(T),
                "  sum_x::", only(Base.return_types(sum_x, (typeof(v),))))
    end

    println()
    println("="^78)
    println("Hot loop over ", N, " elements (best of 5)")
    println("="^78)
    for (name, v) in boxes
        t = best_time(sum_x, v)
        sum_x(v)                  # warm up for the allocation measurement
        println(rpad(name, 27), lpad(round(t * 1e3, digits = 2), 8), " ms   ",
                lpad(@allocated(sum_x(v)), 12), " bytes")
    end

    println()
    println("="^78)
    println("Low-level layout")
    println("="^78)
    for T in (UntypedBox, AbstractBox, TypedBox, ParamBox{Float64})
        println(rpad(string(T), 20),
                " fieldnames=", fieldnames(T),
                "  fieldtypes=", fieldtypes(T),
                "  sizeof=", sizeof(T(1.0, 0)),
                "  offsets=", [fieldoffset(T, i) for i in 1:fieldcount(T)])
    end
end

main()
