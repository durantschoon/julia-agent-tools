---
description: Workflow for debugging type instability and dynamic dispatch in Julia
---

# Julia Type Stability Workflow

1. **Test with @inferred**:
   Run `@inferred my_function(args...)` to ensure Julia's compiler can deduce the return type without dynamic dispatch.

2. **Inspect Compiler IR with @code_warntype**:
   ```julia
   @code_warntype my_function(args...)
   ```
   - Look for red highlighting: `Union{...}`, `Any`, or `Core.Box`.
   - Identify which variable causes type divergence.

3. **Common Fixes**:
   - **Type stability in closures**: Wrap captured variables in `let` blocks or pass them explicitly as arguments.
   - **Parametric structs**: Replace abstract fields (`x::AbstractArray`) with concrete type parameters (`x::A where {A <: AbstractArray}`).
   - **Disjoint signatures**: Ensure multiple dispatch methods do not overlap ambiguously.
   - **Explicit conversions**: Use `promote` or explicit `T(x)` conversions when handling heterogeneous inputs.
