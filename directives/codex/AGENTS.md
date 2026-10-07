# Autonomous Agent Directives for Julia (Codex / Agents)

## Agent Mission & Operating Principles
You are an autonomous AI software engineer writing high-performance Julia code.
Your code must meet the highest standards of the Julia ecosystem:
1. **Zero-allocation on hot numeric paths**: No garbage collection jitter.
2. **Strict type stability**: Predictable JIT compilation, zero dynamic boxing.
3. **Disjoint dispatch**: Avoid method overwriting and precompilation failures.
4. **Token-efficient navigation**: Leverage AST search (`sg`), symbols (`ctags`), and knowledge graphs (`graphify`).

---

## Agent Invariants

### Invariant 1: Method Signatures Must Be Disjoint
Julia's precompilation throws fatal errors when overloaded methods overlap ambiguously:
```julia
# ❌ FAILS PRECOMPILATION (Method overwriting not permitted):
from_scalar(s::T) where {T <: Real} = ...
from_scalar(s::Real) = ...

# ✅ CORRECT:
from_scalar(s::T) where {T <: AbstractFloat} = ...
from_scalar(s::Real) = from_scalar(Float64(s))
```
`ast-grep scan` reports the failing pair as `lint-overlapping-supertype-method`.

### Invariant 2: Value Semantics & Mutation Symmetry
For high-throughput geometric or algebraic operations:
1. Provide a functional, immutable pure method returning a value-type:
   ```julia
   @inline *(a::Multivector32{T}, b::Multivector32{T}) where {T} -> Multivector32{T}
   ```
2. Provide a mutating zero-allocation method writing into a preallocated buffer:
   ```julia
   @inline mul!(buf::Multivector32{T}, a::Multivector32{T}, b::Multivector32{T}) where {T} -> Nothing
   ```

### Invariant 3: Measurement Hygiene for `@allocated`
Do NOT evaluate `@allocated` in global script or test frame scope:
```julia
# ❌ WILL REPORT FALSE ALLOCATIONS (due to global capture boxing):
@test @allocated(a * b) == 0

# ✅ CORRECT (isolate in compiled local function frame):
function test_alloc_free(x, y)
    @allocated(x * y)
end
@test test_alloc_free(a, b) == 0
```
`ast-grep scan` reports the first form as `lint-allocated-outside-function`.

### Invariant 4: Fully Parametrized Struct Fields
Every field in every struct must have a concrete type or concrete type parameter:
```julia
# ❌ SEVERE DE-OPTIMIZATION (Pointer boxing, dynamic dispatch):
struct Joint
    axis::AbstractVector
end

# ✅ OPTIMIZED:
struct Joint{T <: Real}
    axis::SVector{3, T}
end
```

### Invariant 5: Safe JSON Ingestion
Empty JSON arrays in `JSON3` parse to `Union{}`. Prevent `ArgumentError` by explicitly casting numeric values during ingestion:
```julia
val = Float64(entry[:value])
```

### Invariant 6: Inner Constructors Guard Type Parameters
A type parameter that carries meaning (a size, a tag, a unit) is only an invariant once the generated default constructor is gone. Declare an inner constructor that checks it:
```julia
# ❌ ANY K ACCEPTED (default constructor skips every check; lint-unchecked-type-parameter):
struct Tagged{K, T}
    data::Vector{T}
end

# ✅ CORRECT (one inner constructor suppresses the defaults):
struct Tagged{K, T}
    data::Vector{T}
    function Tagged{K, T}(data::Vector{T}) where {K, T}
        length(data) == K || throw(ArgumentError("expected $K entries"))
        return new{K, T}(data)
    end
end
```

### Invariant 7: Methods, Not Adapter Names
Accept a new argument type by adding a method to the existing function, not by porting `from_x` / `compute_y_with_z` adapter names. Dispatch then rejects a wrongly typed argument with a `MethodError`:
```julia
# ❌ area_from_lengths(w::Length, h::Length)
# ✅ area(w::Length, h::Length) = area(meters(w), meters(h))
```

### Invariant 8: The Oracle Is the Public API
Tests compare exported functions against the oracle. Test a converting method against the raw call on the same converted inputs, never against a typed-in decimal (`9.0 * 1e-3 !== 0.009`). A test helper that reimplements the behaviour under test hides a gap; delete it or move it into the package:
```julia
# ❌ @test normalise_in_test(raw) == expected
# ✅ @test MyPkg.parse_terms(raw) == expected
# ✅ @test area(cm(90.0), cm(10.0)) === area(meters(cm(90.0)), meters(cm(10.0)))
```
Use `===` only on immutable values; on a `Vector` it compares identity.

### Invariant 9: Check New Names Against the Loaded Module
Before defining or exporting a top-level name, check it against the built package, whose bindings include everything its `using` statements imported. `isdefined(Base, sym)` is not enough:
```julia
filter(s -> isdefined(MyPkg, s), [:NewNameA, :NewNameB])   # must be empty
@test isempty(Test.detect_ambiguities(MyPkg; recursive = false))
```

### Invariant 10: Thread Only Memoryless Kernels
Threaded results equal serial results bit for bit only when the kernel is element-wise: no reduction, no accumulator, no `@fastmath`, no mutable globals. Add a separate `f_parallel!` entry point that calls the serial kernel per chunk; never make an existing function start spawning tasks. Before starting, search for `Ref{` and non-`const` globals and run the suite at `-t 1` and `-t 4`; afterwards assert `==` (not `≈`) between the two paths.

---

## Agent Fast Verification Loop

Before declaring any task or stage complete, run the verification cascade:

```bash
# 1. Structural AST Audit
ast-grep scan

# 2. Test Suite
julia --project=. -e 'using Pkg; Pkg.test()'

# 3. Allocation & Type-Warntype Check
julia --project=. -e '
using Test, MyModule
@test (@inferred MyModule.core_op(sample_arg)) !== nothing
'

# 4. Update Architectural Knowledge Graph
graphify update .
```
