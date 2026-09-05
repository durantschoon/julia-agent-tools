# julia-agent-tools

High-performance Developer & LLM Agent Tooling for Julia.

Provides:
- **`ast-grep` Tree-Sitter Support for Julia**: Native AST matching, structural search, and linting rules for Julia codebases.
- **Agent Directives & Rules**: Pre-configured `AGENTS.md`, `CLAUDE.md`, and Antigravity rules (`.agents/rules/`) tuned specifically for Julia development.
- **Universal Ctags Optlib Rules**: Jump-to-definition rules for Julia structs, multiple dispatch methods, macros, and modules.
- **Knowledge Graph Integration**: Zero-token architectural indexing via `graphify`.

---

## 1. Quick Setup: ast-grep for Julia

`ast-grep` (`sg`) provides lightning-fast structural code search. To use it in any Julia repository:

1. Install `ast-grep`:
   ```bash
   brew install ast-grep
   ```
2. Build the universal Tree-sitter dylib:
   ```bash
   make dylib
   ```
3. Copy `sgconfig.yml` and the `rules/` directory into your project root:
   ```bash
   ast-grep scan
   ```

### Example Structural Searches

Find all struct definitions:
```bash
ast-grep run -k struct_definition
```

Find all function definitions:
```bash
ast-grep run -k function_definition
```

Find functions with `@inline` annotations:
```bash
ast-grep run -k macro_definition
```

---

## 2. LLM Agent Directives

Drop-in guidelines for AI coding assistants:
- `directives/claude/CLAUDE.md`: Claude Code instructions and PreToolUse hooks.
- `directives/codex/AGENTS.md`: Codex instructions for Julia multiple dispatch and type stability.
- `directives/antigravity/`: Antigravity rules and workflows.
- `directives/cursor/`: Cursor `.cursorrules` for Julia.

---

## License
MIT License.
