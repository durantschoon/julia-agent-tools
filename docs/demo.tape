# Sixty-second demo for the README and the announcement. Render with:
#   brew install vhs          # pulls ttyd and ffmpeg
#   vhs docs/demo.tape        # writes docs/demo.gif
# Run from the repo root after `make dylib`. Keep it under a minute.

Output docs/demo.gif
Set Shell zsh
Set FontSize 16
Set Width 1100
Set Height 600
Set Theme "Catppuccin Mocha"
Set TypingSpeed 40ms

Type "# 1. Lint a file by syntax, not regex: two classic Julia pitfalls" Enter
Sleep 1s
Type "cat docs/demo/particle.jl" Enter
Sleep 2.5s
Type "./bin/julia-agent-tools scan docs/demo" Enter
Sleep 6s

Type "clear" Enter
Type "# 2. Structural search by AST node kind: every parametric method" Enter
Sleep 1s
Type "./bin/julia-agent-tools run -k where_expression docs/demo" Enter
Sleep 5s

Type "clear" Enter
Type "# 3. Ctags for Julia, so jump-to-definition works in any editor" Enter
Sleep 1s
Type "./bin/julia-agent-tools tags docs/demo /tmp/tags && grep -v '^!' /tmp/tags | cut -f1,4" Enter
Sleep 4s

Type "clear" Enter
Type "# 4. The rule suite the agents are held to" Enter
Sleep 1s
Type "make test-ast 2>&1 | tail -3" Enter
Sleep 6s
