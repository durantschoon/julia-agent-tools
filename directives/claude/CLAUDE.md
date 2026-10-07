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
  `ast-grep scan` flags `@allocated` outside a function body (`lint-allocated-outside-function`).

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
- **Check**: `ast-grep scan` flags a single-argument `f(::S)` beside `f(::T) where {T <: S}` in the same scope (`lint-overlapping-supertype-method`).

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

### 6. Inner Constructors Guard Type Parameters
- **Rule**: A struct whose type parameter carries meaning (a size, a tag, a unit) MUST declare an inner constructor that checks it. Route every public way of building the type through that check.
- **Why**: Julia generates a default constructor for every struct without one. If a parameter is not tied to a field, `Tagged{3, Float64}(data)` accepts any data, and checked factory functions beside it are only advisory.
- **How to check**: `ast-grep scan` flags a parameter no field uses in a struct with no inner constructor (`lint-unchecked-type-parameter`). Then try the direct spelling with bad input and confirm it throws:
  ```julia
  struct Tagged{K, T}
      data::Vector{T}
      function Tagged{K, T}(data::Vector{T}) where {K, T}
          length(data) == K || throw(ArgumentError("expected $K entries"))
          return new{K, T}(data)
      end
  end
  @test_throws ArgumentError Tagged{3, Float64}([1.0])
  ```

### 7. Methods, Not Adapter Names
- **Rule**: To accept a new argument type, add a method to the existing function. Do not port `from_x` / `compute_y_with_z` style adapter names from languages without overloading.
- **Why**: A method keeps one name per operation, and dispatch turns a wrongly typed argument into a `MethodError` instead of a silent unit or order mix-up.
- **How to check**: `methods(f)` lists the typed method beside the raw one; no new exported name was needed for it.

### 8. The Oracle Is the Public API
- **Rule**: Tests compare the library's exported functions against the oracle. A typed or converting method is tested against the raw call on the same converted inputs (`===` for bits types), not against a decimal literal. No test helper may reimplement the behaviour under test.
- **Why**: `9.0 * 1e-3 !== 0.009`, so a transcribed constant is a different oracle. And a decoder in the test file that "fixes" the data makes the assertion pass whatever the library does.
- **How to check**: every oracle assertion's left-hand side is a call into the package. `===` is used only on immutable values (on a `Vector` it compares identity).

### 9. Check New Names Against the Loaded Module
- **Rule**: Before exporting or defining a new top-level name, check it against the built module, not only `Base`. After adding methods to `Base` operators, run `Test.detect_ambiguities`.
- **Why**: Names imported by the package's own `using` statements are already bound inside it; redefining one is a load error, and `isdefined(Base, sym)` cannot see it.
- **How to check**:
  ```julia
  filter(s -> isdefined(MyPkg, s), [:NewNameA, :NewNameB])   # must be empty
  @test isempty(Test.detect_ambiguities(MyPkg; recursive = false))
  ```

### 10. Thread Only Memoryless Kernels
- **Rule**: Add threading as a separate entry point (`f_parallel!`) over an element-wise kernel that each chunk calls unchanged. Do not make an existing function start spawning tasks.
- **Why**: Results are bit-identical to the serial path only when the kernel has no reduction, no running accumulator, no `@fastmath` and no mutable global state. An existing call site that suddenly spawns changes its allocations and its behaviour inside a caller's own parallel region.
- **How to check**: search the package for mutable globals (`Ref{`, non-`const` globals) before starting; run the suite at `-t 1` and `-t 4` on the unchanged code; assert `==` (not `≈`) between serial and threaded output at several sizes and chunk counts.
