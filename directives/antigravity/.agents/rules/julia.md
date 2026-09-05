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

## Standard Commands
- Test: `julia --project=. -e 'using Pkg; Pkg.test()'`
- AST Lint: `ast-grep scan`
- Index Symbols: `ctags --options=ctags.d/julia.ctags -R src`
