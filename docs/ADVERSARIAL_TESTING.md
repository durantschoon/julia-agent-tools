# Adversarial Testing Results (Pre-Launch QA)

This document records the skeptical / adversarial testing performed prior to the public launch. We intentionally tried to break the tooling to ensure resilience.

## Test 1: Cold Start Build (\`make dylib\`)
**Goal:** Verify that the tree-sitter C code compiles universally (x86_64/arm64) on a clean slate without missing dependencies.
**Execution:** \`make clean && make dylib\`
**Result:** Passed ✅
**Notes:** Successfully compiled \`tree-sitter-julia.dylib\`. Emitted minor, harmless \`ld\` warnings about a Homebrew gcc search path, but the Apple \`clang\` linker successfully produced the universal binary.

## Test 2: ast-grep Evasion (`lint-untyped-struct-field`)
**Goal:** Trick the `ast-grep` rules into passing a struct that causes heap allocations / type instability.
**Execution:** Created `test_dirty.jl` with an untyped struct (`data`, `value`). Then changed it to abstractly typed fields (`data::AbstractArray`, `value::Number`).
**Result:** Passed, with a caveat 🟡
**Notes:** The `lint-untyped-struct-field` rule perfectly caught the raw untyped fields (`data`, `value`). However, when I typed them as abstract types (`data::AbstractArray`), the linter ignored them because they are wrapped in a `typed_expression`. While this correctly filters for the explicit absence of types, users might still create type-instabilities by using abstract types in structs.

## Test 2B: Writing `lint-abstract-struct-field.yml`
**Goal:** Patch the loophole discovered in Test 2 by creating a strict linter for generic/abstract types inside struct definitions.
**Execution:** Created a new ast-grep rule checking for `FIELD::TYPE` constraints where `TYPE` matches `^(Abstract.*|Any|Number|Real|Integer|Function)$`. Scanned `test_dirty.jl` containing `data::AbstractArray`, `value::Number`, and `valid::Float64`.
**Result:** Passed ✅
**Notes:** The rule successfully threw warnings on `AbstractArray` and `Number` recommending struct parameterization, while completely ignoring the strictly-typed `Float64` field. 
