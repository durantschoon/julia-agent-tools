# julia-agent-tools

High-performance Developer & LLM Agent Tooling for Julia.

Provides:
- **`ast-grep` Tree-Sitter Support for Julia**: Native AST pattern matching, structural search, and structural linting rules for Julia codebases.
- **Universal Ctags Optlib Rules**: Jump-to-definition tags for Julia abstract types, composite structs (mutable vs immutable), methods, macros, modules, and type aliases.
- **Agent Directives & Rules**: Battle-tested drop-ins for `CLAUDE.md`, `AGENTS.md`, Cursor (`.cursorrules`), and Antigravity (`.agents/rules/`, workflows) enforcing type stability, zero-allocation hot paths, and precompilation hygiene.
- **`JuliaAgentTools.jl` Package**: Standard Julia package API for memory allocation audits, type stability validation, tags generation, and directive installation.
- **CLI Utility**: `bin/julia-agent-tools` for zero-friction command-line scanning, running, and tagging.
- **Lessons** ([`docs/lessons.md`](docs/lessons.md)): twelve Julia pitfalls met while building a library with coding agents, each as symptom, cause, rule and example. The directives and `lint-*` rules are drawn from them.

---

## 1. ast-grep (`sg`) Tree-Sitter Support for Julia

`ast-grep` provides fast structural code search and linting.

### Setup & Compilation
```bash
# 1. Install ast-grep
brew install ast-grep

# 2. Build the Tree-sitter dylib (macOS universal arm64/x86_64 or Linux)
make dylib

# 3. Run rule tests
make test-ast
```

### Pre-Configured Rule Catalogue (`rules/`)

| Rule ID | Description | Match Kind |
| :--- | :--- | :--- |
| `find-structs` | All struct definitions | `struct_definition` |
| `find-mutable-structs` | Mutable structs (heap allocated) | `struct_definition` with `mutable` |
| `find-abstract-types` | Abstract type hierarchies | `abstract_definition` |
| `find-functions` | Standard function definitions | `function_definition` |
| `find-short-functions` | One-liner assignments `f(x) = expr` | `assignment` with lhs call |
| `find-parametric-methods` | Multiple dispatch with `where` clauses | `where_expression` |
| `find-macros` | Macro definitions | `macro_definition` |
| `find-macrocalls` | Macro invocations (`@inline`, `@inbounds`, etc.) | `macrocall_expression` |
| `find-modules` | Module and submodule boundaries | `module_definition` |
| `find-type-assertions` | Explicit type annotations `x::T` | `typed_expression` |
| `find-inbounds` | Loop / block `@inbounds` annotations | `@inbounds` |
| `find-simd` | Loop vectorization `@simd` annotations | `@simd` |
| `find-generated` | `@generated` metaprogrammed functions | `@generated` |
| `lint-untyped-struct-field` | Flags untyped struct fields (causes boxing) | `identifier` field |
| `lint-abstract-struct-field` | Flags abstract or over-generic field types (`Any`, `Number`, `Abstract*`) | `typed_expression` in a struct |
| `lint-allocated-outside-function` | Flags `@allocated` at top level, where it measures the wrong thing | `macrocall_expression` |
| `lint-overlapping-supertype-method` | Flags a `::Real`-style method beside a `where {T <: Real}` method of the same name (precompilation overwrite) | neighbouring `function_definition`s |
| `lint-unchecked-type-parameter` | Flags a struct with a type parameter but no inner constructor to guard it | `struct_definition` |

### CLI Usage
```bash
# Scan a directory against all Julia rules:
./bin/julia-agent-tools scan src/

# Run a structural query by AST node kind:
./bin/julia-agent-tools run -k struct_definition src/

# Run a structural query for parametric methods:
./bin/julia-agent-tools run -k where_expression src/
```

---

## 2. Universal Ctags Optlib (`ctags.d/julia.ctags`)

Brings instant symbol jump-to-definition and token-free agent navigation to Julia codebases.

### Supported Language Kinds
- `a`: Abstract types (`abstract type ... end`)
- `M`: Mutable structs (`mutable struct ... end`)
- `s`: Immutable structs (`struct ... end`)
- `e`: Enums (`@enum ...`)
- `T`: Type aliases (`const Alias = Type{...}`)
- `f`: Functions (both standard and short-form `f(x) = ...`)
- `m`: Macros (`macro ... end`)
- `n`: Modules (`module ... end`)
- `c`: Constants (`const ...`)

### Generating Tags
```bash
# Project-level generation:
./bin/julia-agent-tools tags src/ tags

# Or install globally for Universal Ctags:
make install-ctags
```

---

## 3. LLM Agent Directives (`directives/`)

Drop-in directives for autonomous coding agents:
- **`directives/claude/CLAUDE.md`**: Tailored for Claude Code agents. Includes test commands, AST structural search recipes, zero-allocation rules, and precompilation hygiene.
- **`directives/codex/AGENTS.md`**: Operating principles for autonomous codex/agent workers (disjoint method signatures, compiled allocation scope, static array semantics).
- **`directives/antigravity/`**: Antigravity rules (`.agents/rules/julia.md`) and workflows (`benchmarking.md`, `type-stability.md`).
- **`directives/cursor/`**: `.cursorrules` optimized for Julia development.

### Installing Directives to a Target Repository
```bash
# Via CLI:
./bin/julia-agent-tools install-directives /path/to/my-julia-repo

# Or via Julia package:
julia -e 'using JuliaAgentTools; install_directives("/path/to/my-julia-repo")'
```

---

## 4. `JuliaAgentTools.jl` Julia Package

Use programmatically inside Julia or REPL:

```julia
using JuliaAgentTools

# 1. Zero-allocation verification (immune to dynamic scope capture)
my_mul(a, b) = a * b
bytes = audit_allocations(my_mul, 1.5, 2.5)
@assert bytes == 0 "Detected allocation!"

# 2. Type stability auditing
is_stable = is_type_stable(my_mul, (Float64, Float64)) # returns true

# 3. Generate Universal Ctags
JuliaAgentTools.generate_tags("src"; output="tags")

# 4. Install agent directives
JuliaAgentTools.install_directives("/path/to/target/repo"; agent=:all)
```

---

## 5. Verification & Testing

Run all unit test suites across ast-grep, Universal Ctags, and the Julia package:
```bash
make test
```

Run real-world multi-repo corpus stress-testing:
```bash
make test-corpus
```

Expected output:
- `ast-grep`: 17 passed, 0 failed.
- Universal Ctags: all tag assertions passed.
- `JuliaAgentTools`: 13 passed, 0 failed.
- Corpus stress-testing: 63+ real-world files scanned with 0 errors across thousands of AST constructs.


---

## Works with graphify

[graphify](https://github.com/Graphify-Labs/graphify) (`uv tool install graphifyy`; the PyPI name has two y's) builds a knowledge graph of a codebase from its syntax tree, which
agents query for architecture and relationships instead of reading files
one by one. It is a separate tool, not shipped here; its Julia graphs rest on
the same upstream `tree-sitter-julia` grammar this repo vendors and builds,
and the directives tell agents to query the graph for architecture and
relationships and to refresh it after changing code. The three commands the Claude directive lists:

```bash
graphify query "<concept or question>"     # ask about architecture or relationships
graphify path "<SymbolA>" "<SymbolB>"      # how two symbols connect
graphify update .                          # refresh the graph after code changes
```

Its output directory, `graphify-out/`, is already in `.gitignore`.

---

## License
MIT License.
