#!/usr/bin/env bash
# A/B: the same ten editing tasks, done by a headless agent on a bare copy and on a copy
# with julia-agent-tools' directives installed; scored by lint hits and the test suite.
set -uo pipefail
export PATH="$HOME/.juliaup/bin:$PATH"
S=$(cd "$(dirname "$0")" && pwd); JAT=$(cd "$S/../.." && pwd)   # this repo, with `make dylib` already run; SRC=${1:?usage: ab.sh /path/to/a/julia/project}
SCAN="guix shell ast-grep -- ast-grep scan -c $JAT/sgconfig.yml --filter ^lint-"
log() { printf '%s %s\n' "$(date '+%H:%M:%S')" "$*" | tee -a "$S/run.log"; }
lint_hits() { $SCAN "$1/src" "$1/test" 2>/dev/null | grep -c -E '^(warning|error)\[' || true; }

# Positive control: the scanner must see a known-bad snippet, or the numbers mean nothing.
ctrl=$(mktemp -d); printf 'struct Bad\n    data\n    value::Any\nend\n' > "$ctrl/bad.jl"
hits=$($SCAN "$ctrl" 2>/dev/null | grep -c -E '^(warning|error)\[' || true)
log "positive control: $hits lint hit(s) on a known-bad struct"; [ "$hits" -ge 1 ] || { log "ABORT: scanner saw nothing"; exit 1; }

for side in bare tooled; do
  rm -rf "$S/$side"; git clone -q "$SRC" "$S/$side"
  rm -rf "$S/$side/.claude" "$S/$side/.agents" "$S/$side/.codex"     # host-specific hooks would break the agent on Linux; same on both sides
  git -C "$S/$side" add -A && git -C "$S/$side" commit -q -m "ab: baseline ($side)" --allow-empty
done
julia --project="$JAT" -e 'using JuliaAgentTools; install_directives(ARGS[1]; overwrite=true)' "$S/tooled" >> "$S/run.log" 2>&1
git -C "$S/tooled" add -A && git -C "$S/tooled" commit -q -m "ab: directives installed"
for side in bare tooled; do (cd "$S/$side" && julia --project=. -e 'using Pkg; Pkg.instantiate()' >> "$S/run.log" 2>&1); done
base_bare=$(lint_hits "$S/bare"); base_tooled=$(lint_hits "$S/tooled")
log "baseline lint hits: bare=$base_bare tooled=$base_tooled"
printf 'side\ttask\tlint_delta\ttests\tfiles_changed\tagent_exit\n' > "$S/scores.tsv"

i=0
while IFS= read -r task; do i=$((i+1))
  for side in bare tooled; do
    copy="$S/$side"; base=$([ "$side" = bare ] && echo "$base_bare" || echo "$base_tooled")
    git -C "$copy" checkout -q main && git -C "$copy" clean -fdq && git -C "$copy" checkout -q -b "task-$i"
    log "task $i $side: agent start"
    prompt="In this Julia package: $task Put new code in src/ (a new file included from the main module is fine) and tests in test/. Keep the change small, then stop."
    (cd "$copy" && timeout 1200 env -u CLAUDECODE claude -p --permission-mode acceptEdits --allowedTools "Edit,Write,Read,Glob,Grep,Bash(julia:*),Bash(make:*)" --max-turns 40 --output-format text "$prompt" < /dev/null > "$S/log-$side-$i.txt" 2>&1); agent_exit=$?
    git -C "$copy" add -A; git -C "$copy" commit -q -m "task $i" --allow-empty
    files=$(git -C "$copy" diff --name-only main | wc -l | tr -d ' ')
    hits=$(lint_hits "$copy"); delta=$((hits - base))
    (cd "$copy" && timeout 900 julia --project=. -e 'using Pkg; Pkg.test()' > "$S/test-$side-$i.txt" 2>&1) && tests=pass || tests=FAIL
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$side" "$i" "$delta" "$tests" "$files" "$agent_exit" >> "$S/scores.tsv"
    log "task $i $side: lint_delta=$delta tests=$tests files=$files agent_exit=$agent_exit"
  done
done < "$S/tasks.txt"
log "done"; cat "$S/scores.tsv"
