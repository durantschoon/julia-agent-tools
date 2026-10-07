---
description: High-performance Julia engineering standards and agent execution rules
globs: ["**/*.jl"]
---

# Julia Engineering Rules for Antigravity

## Core Directives
1. **Type Stability**: All functions on hot paths must be inferrable by Julia's type inference engine. Verify with `@inferred` and `@code_warntype`.
2. **Zero Allocations**: Pure numerical calculations must not allocate dynamic memory on the heap. Use immutable structs, stack allocations (`SVector`), and mutating `!` functions.
3. **Disjoint Method Signatures**: Never write overlapping method signatures that trigger Julia's precompilation overwrite warnings or errors.
4. **Isolated Benchmark Scope**: Always benchmark and test `@allocated` inside a compiled function to avoid false-positive boxing allocations from the global/REPL scope.
5. **Structural Search**: Use `ast-grep` (`sg`) to query code structure rather than unconstrained grep when analyzing Julia AST patterns.
6. **Inner Constructors Guard Type Parameters**: A struct whose type parameter carries meaning (a size, a tag, a unit) must declare an inner constructor that checks it. The generated default constructor accepts any value for a parameter no field uses (`lint-unchecked-type-parameter`).
7. **Methods, Not Adapter Names**: Accept a new argument type by adding a method to the existing function, not a `from_x` / `compute_y_with_z` adapter name, so dispatch rejects a wrong type with a `MethodError`.
8. **The Oracle Is the Public API**: Tests compare exported functions against the oracle. Test a converting method against the raw call on the same inputs, not a typed-in decimal (`9.0 * 1e-3 !== 0.009`). Never keep a test helper that reimplements the behaviour under test. Use `===` only on immutable values.
9. **Check New Names Against the Loaded Module**: Before defining or exporting a name, check `isdefined(MyPkg, sym)` on the built package, not only `Base`; run `Test.detect_ambiguities` after adding methods to `Base` operators.
10. **Thread Only Memoryless Kernels**: Add threading as a separate `f_parallel!` over an element-wise kernel with no reduction, accumulator, `@fastmath` or mutable globals; never make an existing function spawn tasks. Assert `==` between serial and threaded results.

Rules 3 and 4 are checked by `ast-grep scan` (`lint-overlapping-supertype-method`, `lint-allocated-outside-function`).

## Standard Commands
- Test: `julia --project=. -e 'using Pkg; Pkg.test()'`
- AST Lint: `ast-grep scan`
- Index Symbols: `ctags --options=ctags.d/julia.ctags -R src`
