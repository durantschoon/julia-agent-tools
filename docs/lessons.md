# Lessons: writing Julia with coding agents

General lessons from building a performance-sensitive Julia library with
coding agents. Each one is a mistake that was actually made, or nearly
made, and the rule that came out of it. The agent directives in
`directives/` carry the short form of the ones that are rules of conduct;
the `lint-*` rules in `rules/` catch the ones that are visible in syntax.

Each lesson is laid out as **symptom**, **cause**, **rule**, **example**.

---

## 1. Two signatures that look different can be the same method

- **Symptom**: the package loads in the REPL but precompilation aborts with
  `Method overwriting is not permitted during Module precompilation`.
- **Cause**: `f(x::T) where {T <: Real}` and `f(x::Real)` are the same
  signature to Julia. The second definition replaces the first instead of
  adding a method, and precompilation refuses to overwrite.
- **Rule**: make the parametric method and the fallback disjoint. Narrow the
  type bound on one of them; never rely on "the generic one" and "the
  specific one" being different when only the spelling differs.
- **Example**:
  ```julia
  # Same signature twice: the second overwrites the first.
  half(x::T) where {T <: Real} = x / 2
  half(x::Real) = half(float(x))

  # Disjoint: floats take the fast path, everything else converts first.
  half(x::T) where {T <: AbstractFloat} = x / 2
  half(x::Real) = half(Float64(x))
  ```
  Lint: `lint-overlapping-supertype-method`.

## 2. Measure allocations inside a function, never at top level

- **Symptom**: `@allocated` reports a few dozen bytes for code that should
  allocate nothing, and the number changes between a script and a test set.
- **Cause**: at top level (including inside `@testset`) the operands are
  untyped globals. The measurement includes boxing and dynamic dispatch at
  the call site, not the code under test.
- **Rule**: wrap the measured call in a function and assert on that
  function's result. Call it once first so compilation is not counted.
- **Example**:
  ```julia
  bytes_for(a, b) = @allocated a * b
  bytes_for(x, y)              # warm up
  @test bytes_for(x, y) == 0
  ```
  Lint: `lint-allocated-outside-function`.

## 3. Pair every value-returning hot operation with an in-place one

- **Symptom**: an operation on a fixed-size value is fast in isolation but
  allocates once per call inside a loop.
- **Cause**: building the result in a temporary mutable buffer and
  returning it as a new object can force a heap allocation when the
  buffer escapes the function.
- **Rule**: offer both forms. The functional form (`c = a * b`) is for
  clarity; the mutating form (`mul!(c, a, b)`) writes into a buffer the
  caller owns and is the one the hot loop uses. Check the mutating form
  allocates zero bytes (lesson 2).
- **Example**:
  ```julia
  function scaled!(out::Vector{T}, a::Vector{T}, s::T) where {T}
      @inbounds for i in eachindex(out, a)
          out[i] = s * a[i]
      end
      return out
  end
  scaled(a, s) = scaled!(similar(a), a, s)
  ```

## 4. Abstract field types make every access dynamic

- **Symptom**: `@code_warntype` shows `Any` or a `Union` where a field is
  read; a loop over a struct's data allocates on every iteration.
- **Cause**: a field declared `::AbstractVector`, `::Real` or not declared
  at all has no concrete type, so the compiler cannot specialise code that
  reads it. Nesting such a struct inside another spreads the problem.
- **Rule**: give every field a concrete type or a type parameter, all the
  way down. A container of abstractly typed elements is acceptable only
  where you have measured that dispatch on it is not the bottleneck.
- **Example**:
  ```julia
  struct LooseSamples                         # unstable: abstract field
      data::AbstractVector
  end
  struct Samples{T, V <: AbstractVector{T}}   # stable: concrete per instance
      data::V
  end
  ```
  Lint: `lint-abstract-struct-field`, `lint-untyped-struct-field`.

## 5. Standard libraries have fixed UUIDs, and the test target is not free

- **Symptom**: `Pkg.resolve()` looks for an unregistered package called
  `LinearAlgebra`; or `using Random` works in the REPL and fails under
  `Pkg.test()`.
- **Cause**: a hand-written `[deps]` entry with an invented UUID names a
  different package. And a test environment only sees what `[extras]` and
  `[targets]` list, standard libraries included.
- **Rule**: take a stdlib's UUID from Julia, not from memory, and check the
  test target before using a stdlib in tests.
- **Example**:
  ```julia
  Base.identify_package("LinearAlgebra").uuid
  # UUID("37e2e46d-f89d-539d-b4ee-838fcccc9c8e")
  ```

## 6. Lay batches out as structure-of-arrays for SIMD

- **Symptom**: a loop over a `Vector` of small structs runs far slower than
  the arithmetic suggests.
- **Cause**: an array of structs interleaves the components in memory, so
  the loop cannot load several values of the same component at once.
- **Rule**: for batch kernels, store one contiguous vector per component
  and write the loop over the index with `@simd`. Decide early whether
  those fields are `Vector{T}` or `AbstractVector{T}`: only the second
  accepts a `view`, which is what lets you later split the batch into
  chunks without copying.
- **Example**:
  ```julia
  struct Points{T, V <: AbstractVector{T}}
      x::V
      y::V
  end
  function shift!(p::Points, dx, dy)
      @inbounds @simd for i in eachindex(p.x, p.y)
          p.x[i] += dx
          p.y[i] += dy
      end
      return p
  end
  ```

## 7. A type parameter is not an invariant until the default constructor is gone

- **Symptom**: a parametric struct documents "the `K` parameter is always
  checked", yet `Tagged{3, Float64}(data)` with the wrong data succeeds.
- **Cause**: Julia generates a default constructor for every struct. When a
  parameter is not tied to any field, that constructor accepts any value
  for it, and every checked factory function beside it is only advisory.
- **Rule**: declare at least one inner constructor; that suppresses the
  defaults. Put the check there, or make the inner constructor take a
  private tag and route every public spelling through the checked path.
- **Example**:
  ```julia
  struct Tagged{K, T}
      data::Vector{T}
      function Tagged{K, T}(data::Vector{T}) where {K, T}
          length(data) == K || throw(ArgumentError("expected $K entries"))
          return new{K, T}(data)
      end
  end
  ```
  Lint: `lint-unchecked-type-parameter`.

## 8. Dispatch is the adapter, and the test oracle is the raw call

- **Symptom**: a port from another language grows `from_x`, `compute_y_as_z`
  style adapter functions; a test comparing an adapter against a written-out
  decimal fails by one unit in the last place.
- **Cause**: languages without overloading need a new name per argument
  type; Julia does not. And `9.0 * 1e-3` is not the same `Float64` as the
  literal `0.009`, so a transcribed constant is a different oracle from the
  computation it stands for.
- **Rule**: add a method to the existing function instead of a new name, so
  a wrongly typed argument is a `MethodError`. Test the new method against
  the raw call on the same converted inputs, with `===` for bits types, not
  against a decimal you typed.
- **Example**:
  ```julia
  # Assume a units type `Length`, a constructor `cm` and `meters(::Length)::Float64`.
  area(w::Real, h::Real) = w * h
  area(w::Length, h::Length) = area(meters(w), meters(h))   # a method, not a new name

  @test area(cm(90.0), cm(10.0)) === area(meters(cm(90.0)), meters(cm(10.0)))
  ```
  (`===` compares bits for immutable values but identity for mutable
  ones: two equal `Vector`s are not `===`. Check the type before reaching
  for it.)

## 9. A test helper that implements the behaviour under test is a gap

- **Symptom**: a test against an external oracle has always passed, yet the
  exported function it is meant to cover does something different.
- **Cause**: the test file carries its own decoder or normaliser that does
  the right thing, and the assertion compares the oracle with the helper's
  output rather than with the library's.
- **Rule**: route every oracle comparison through the public API. If a test
  helper is doing real work, that work is either missing from the library
  or the test is checking the helper. Delete it, or move it into the
  library and test it there.
- **Example**:
  ```julia
  # Gap: passes whatever `parse_terms` does.
  @test normalise_in_test(raw) == expected

  # Coverage: fails until the library behaves.
  @test MyPkg.parse_terms(raw) == expected
  ```

## 10. Threading is deterministic when the kernel has no memory

- **Symptom**: you need to promise that a threaded batch function returns
  bit-identical results to the serial one, at any thread count.
- **Cause**: that promise holds only for element-wise kernels: no
  reduction, no running accumulator, no `@fastmath`, and no mutable global
  state. Chunking such a loop changes its bounds and nothing else.
- **Rule**: before writing threaded code, check that the module has no
  mutable globals (a `grep` for `Ref{` and non-constant globals is enough),
  run the suite at several thread counts on the unchanged code, and keep the
  serial kernel as the one implementation each chunk calls. Add the
  threaded variant as a separate name; do not make an existing function
  start spawning tasks.
- **Example**:
  ```julia
  @test scale_threaded!(similar(a), a, 2.0) == scale!(similar(a), a, 2.0)  # ==, not ≈
  # A fast path that must not spawn: a Task allocates, so zero bytes proves it.
  @test bytes_for_threaded_small_input() == 0
  ```

## 11. Check a new export against the built module, not just `Base`

- **Symptom**: adding `const Length = ...` makes the package fail to load,
  or makes `Vector{Float64}` ambiguous in user code.
- **Cause**: the name is already bound, either by `Base` or by a package
  your module brings in with `using`. `isdefined(Base, :Length)` misses the
  second case.
- **Rule**: before exporting new names, check each one against your own
  loaded module, whose bindings include everything its `using` statements
  imported. When methods are added to `Base` operators, also run
  `Test.detect_ambiguities`.
- **Example**:
  ```julia
  using MyPkg, Test
  candidates = [:Length, :Area, :Volume]
  filter(s -> isdefined(MyPkg, s), candidates)        # must be empty before defining
  @test isempty(detect_ambiguities(MyPkg; recursive = false))
  ```

## 12. Default positional arguments define more than one method

- **Symptom**: an assertion such as `length(methods(f)) == 1` fails after
  a harmless-looking signature change.
- **Cause**: `f(a, b, c = 0)` defines `f(a, b)` and `f(a, b, c)`. Each
  default positional argument adds a method.
- **Rule**: assert the property you mean, such as which argument types the
  methods accept, rather than a method count.
- **Example**:
  ```julia
  f(a, b, c = 0) = a + b + c
  length(methods(f))                                  # 2
  @test all(m -> m.sig <: Tuple{typeof(f), Any, Any, Vararg}, methods(f))
  ```
