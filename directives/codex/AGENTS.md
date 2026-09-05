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
