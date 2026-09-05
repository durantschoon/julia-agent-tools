# Julia Project Instructions for Claude Code

## Project Overview & Conventions
- **Language**: Julia (v1.10+)
- **Paradigm**: Multiple dispatch, parametric polymorphism, and high-performance zero-allocation numeric computing.
- **Dependency Management**: Pkg via `Project.toml` and `Manifest.toml`.

---

## Commands & Workflows

### Testing & Verification
```bash
# Run entire test suite
julia --project=. -e 'using Pkg; Pkg.test()'

# Run single test file quickly
julia --project=. test/test_specific.jl

# Run with multi-threading
julia --project=. -t auto -e 'using Pkg; Pkg.test()'
```

### Benchmarking & Allocation Profiling
```bash
# Run BenchmarkTools suite
julia --project=. benchmark/benchmarks.jl

# Run allocation audit
julia --project=. -e 'include("benchmark/allocations.jl")'
```

### AST Structural Search (via ast-grep / sg)
```bash
# Find all structs
ast-grep run -k struct_definition

# Find mutable structs (potential allocation sites)
ast-grep run -k struct_definition -f rules/find-mutable-structs.yml

# Find parametric methods
ast-grep run -k where_expression

# Scan project for AST lint issues
ast-grep scan
```

### Symbol Indexing & Navigation (Universal Ctags)
```bash
# Generate tags with Julia optlib
ctags --options=ctags.d/julia.ctags -R src test
```

### Knowledge Graph (graphify)
```bash
# Query architecture / relationships
graphify query "<concept or question>"
graphify path "<SymbolA>" "<SymbolB>"

# Update graph after code changes
graphify update .
```

---

## Critical Julia Performance & Stability Rules

### 1. Zero-Allocation Hot Paths
- **Immutable Structs**: Hot-path data structures MUST be immutable (`struct`, not `mutable struct`). Immutable value types can be stack-allocated or held in CPU registers.
- **Mutating Buffers**: For operations that write output, provide both a functional returning method (`c = a * b`) and an in-place mutating method (`mul!(c, a, b)`).
- **Static Arrays**: Use `StaticArrays.SVector` for fixed-size coordinate vectors and multivectors instead of standard heap-allocated `Vector`.
- **Measuring `@allocated`**:
  > **Warning**: Never run `@allocated` directly at top-level script/REPL scope. Top-level variables are boxed by dynamic scope frames. ALWAYS wrap the measured invocation inside a compiled function:
  ```julia
  # CORRECT:
  function measure_alloc(a, b)
      @allocated my_product(a, b)
  end
  @test measure_alloc(x, y) == 0
  ```

### 2. Disjoint Signatures & Precompilation Hygiene
- **Method Overwriting Pitfall**:
  Defining `f(s::T) where {T <: Real}` and `f(s::Real)` can cause Julia precompilation to fail with:
  `ERROR: Method overwriting is not permitted during Module precompilation`.
- **Rule**: Keep method signatures disjoint:
  ```julia
  # Disjoint parametric signatures:
  f(s::T) where {T <: AbstractFloat} = ...
  f(s::Real) = f(Float64(s)) # Fallback promotion
  ```

### 3. Type Stability & Compiler Auditing
- Verify type stability using `@inferred`:
  ```julia
  @test (@inferred my_function(x, y)) isa ExpectedType
  ```
- Inspect generated code and boxes:
  ```julia
  @code_warntype my_function(x, y)
  ```
  Look for red `Any`, `Union{...}`, or `Box` annotations and eliminate them.
- Avoid abstract container types: Never type a struct field as `data::AbstractVector`. Use parametric typing:
  ```julia
  # WRONG (type unstable):
  struct Container
      data::AbstractVector
  end

  # RIGHT (fully parameterized):
  struct Container{T, V <: AbstractVector{T}}
      data::V
  end
  ```

### 4. JSON Deserialization Guard
- `JSON3.read` parses empty JSON arrays as `Union{}` element types (e.g. `JSON3.Array{Union{}}`).
- Always explicitly coerce parsed values when building typed structures:
  ```julia
  Float64(val) # Explicit numeric conversion
  ```

### 5. Standard Library UUIDs
- When adding stdlibs (e.g., `LinearAlgebra`, `Test`, `Random`, `SparseArrays`), use canonical Julia standard library UUIDs (e.g., `Base.identify_package("LinearAlgebra").uuid`).
