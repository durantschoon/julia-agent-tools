# julia-agent-tools

Drop-in agent directives, AST linters, and developer tooling that make LLM coding agents (Claude Code, Codex, Cursor, Antigravity) write fast, type-stable, zero-allocation Julia.

Out of the box, coding agents routinely fall into Julia-specific traps: measuring `@allocated` at top level (where it measures global variable boxing instead of the function), defining overlapping parametric methods that fail precompilation, or leaving struct fields untyped or abstractly typed. **Installing the directives from this repo into your Julia project gives your agent the rules—and the structural search, linting, knowledge-graph, and runtime auditing tools—to avoid those pitfalls automatically.**

![julia-agent-tools demo](docs/demo.gif)

Provides:
- **Agent Directives & Rules (`directives/`)**: Battle-tested drop-ins for Claude Code (`CLAUDE.md`), Codex (`AGENTS.md`), Cursor (`.cursorrules`), and Antigravity (`.agents/rules/` and workflows) enforcing type stability, zero-allocation hot paths, and precompilation hygiene.
- **Empirical A/B Evaluation ([`docs/ab-measurement.md`](docs/ab-measurement.md)) & Lessons ([`docs/lessons.md`](docs/lessons.md))**: Twelve real-world Julia pitfalls encountered while building a performance-sensitive library with coding agents, plus a reproducible A/B benchmark showing how installing the directives cuts agent-introduced lint and allocation bugs. [`scripts/untyped_fields_demo.jl`](scripts/untyped_fields_demo.jl) demonstrates field inference, storage and allocation costs, compiler recovery for local values, and abstract versus concrete parametric containers.
- **Code Knowledge Graphs via [graphify](https://github.com/Graphify-Labs/graphify)**: Pairs with graphify (an AST-based code knowledge graph tool) so coding agents query codebase architecture, function call graphs, and type hierarchies instead of blind grepping.
- **`ast-grep` Tree-Sitter Support for Julia**: Native AST pattern matching, structural search, and automated linting rules to catch Julia anti-patterns in milliseconds.
- **Universal Ctags Optlib Rules**: Instant jump-to-definition tags for Julia abstract types, composite structs (mutable vs immutable), methods, macros, modules, and type aliases.
- **`JuliaAgentTools.jl` Package & CLI**: Standard Julia package API and `bin/julia-agent-tools` CLI for directive installation, memory allocation audits, type stability validation, AST scanning, and tags generation.

---

## 1. Quick Start: Install Agent Directives (`directives/`)

The primary workflow is installing the Julia directives into the repository you and your coding agent are working on:

```bash
# Via CLI (installs all directives into your target repo):
./bin/julia-agent-tools install-directives /path/to/my-julia-repo

# Or via Julia (install all, or pick :claude, :codex, :cursor, :antigravity):
julia --project=. -e 'using JuliaAgentTools; install_directives("/path/to/my-julia-repo"; agent=:claude)'
```

### What Gets Installed
- **`directives/claude/CLAUDE.md`**: Tailored for Claude Code. Includes test commands, AST structural search recipes, `graphify` queries, zero-allocation rules, and precompilation hygiene.
- **`directives/codex/AGENTS.md`**: Operating principles for autonomous Codex/agent workers (disjoint method signatures, compiled allocation scope, static array semantics).
- **`directives/antigravity/`**: Antigravity rules (`.agents/rules/julia.md`) and workflows (`benchmarking.md`, `type-stability.md`).
- **`directives/cursor/`**: `.cursorrules` optimized for Julia development.
- **`ctags.d/julia.ctags`**: Universal Ctags configuration for Julia symbols.

> **Does it actually change what the agent writes?**
> See [`docs/ab-measurement.md`](docs/ab-measurement.md) for a controlled A/B test across 10 editing tasks comparing a bare repository against one with `install_directives` applied (and [`docs/lessons.md`](docs/lessons.md) for the 12 specific failure modes behind the rules).

These tools are intended as a practical reliability layer, especially when
you do not have access to the strongest models or want to use smaller, lower-
cost models as spawned coding agents. Frontier models may increasingly handle
Julia idioms without as much explicit guidance, but model capability varies
today, and even capable models can benefit from project-specific instructions
and fast, deterministic checks.

Want to see whether they help on your code? Pick one concrete Julia problem—a
precompilation failure, a flagged struct field, or a hot loop with type
instability or unexpected allocations. Ask your agent to fix it, then rerun
the relevant test, lint, or allocation check. For a useful comparison, try
the same task before and after installing the directives.

---

## 2. ast-grep (`sg`) Tree-Sitter Support for Julia

`ast-grep` provides fast structural code search and linting that both you and your coding agent can run to catch Julia anti-patterns before running tests.

### Setup & Compilation
```bash
# 1. Install ast-grep (pick one for macOS, Linux, or Windows):
brew install ast-grep                 # macOS / Linuxbrew
cargo install ast-grep --locked       # Linux / macOS / Windows ( via Rust )
uv tool install ast-grep-cli          # Linux / macOS / Windows ( or: pipx install ast-grep-cli )
npm install -g @ast-grep/cli          # Linux / macOS / Windows ( via Node.js )

# 2. Build the Tree-sitter dylib (macOS universal arm64/x86_64 or Linux gcc/clang):
make dylib

# 3. Run rule tests:
make test-ast
```

ast-grep 0.50 and later refuse to load native custom-language libraries
(this grammar is one) unless asked. The Makefile, the CLI and the Julia
package pass `--custom-languages allow` when the installed ast-grep knows the
option. If you call `ast-grep` yourself, add `--custom-languages allow`, or
run `ast-grep scan --custom-languages trust -c sgconfig.yml .` once to
remember this project.

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

## 3. Universal Ctags Optlib (`ctags.d/julia.ctags`)

Brings instant symbol jump-to-definition and token-free agent navigation to Julia codebases.

### Installing Universal Ctags
```bash
brew install universal-ctags          # macOS
sudo apt install universal-ctags      # Ubuntu / Debian (or `pacman -S ctags`, `dnf install ctags`)
scoop install universal-ctags         # Windows (or `winget install UniversalCtags.Ctags`)
```

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

## 4. `JuliaAgentTools.jl` Julia Package

Use programmatically inside Julia or REPL:

```julia
using JuliaAgentTools

# 1. Install agent directives (:claude, :codex, :cursor, :antigravity, or :all)
JuliaAgentTools.install_directives("/path/to/target/repo"; agent=:all)

# 2. Zero-allocation verification (immune to dynamic scope capture)
my_mul(a, b) = a * b
bytes = audit_allocations(my_mul, 1.5, 2.5)
@assert bytes == 0 "Detected allocation!"

# 3. Type stability auditing
is_stable = is_type_stable(my_mul, (Float64, Float64)) # returns true

# 4. Generate Universal Ctags
JuliaAgentTools.generate_tags("src"; output="tags")
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
- `ast-grep`: 18 passed, 0 failed.
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
