#!/usr/bin/env bash
# A/B: the same ten editing tasks, done by a headless agent on a bare copy of a Julia
# project and on a copy with this repo's directives installed; scored by lint hits
# (this repo's lint-* rules, minus the project's baseline) and by the project's tests.
#
#   docs/ab/ab.sh /path/to/your/julia/project      # ~90 min for ten tasks
#   docs/ab/ab.sh --check                          # tool versions + scanner self-check, no agent runs
#
# Needs: julia, claude (Claude Code CLI), ast-grep (on PATH, or Guix), and `make dylib`
# run once in this repo. Results go to $AB_OUT, default <runs dir>/<timestamp>/ where the
# runs dir is `git config ab.runsDir` in this checkout, else ~/ab-runs:
# scores.tsv, run.log, one log per agent run, one log per test run, and the two
# clones with one branch per task so every diff can be reviewed.
set -uo pipefail
export PATH="$HOME/.juliaup/bin:$PATH"
HERE=$(cd "$(dirname "$0")" && pwd); JAT=$(cd "$HERE/../.." && pwd)
TASKS="${AB_TASKS:-$HERE/tasks.txt}"
RUNS_DIR=$(git -C "$JAT" config --get ab.runsDir 2>/dev/null || echo "$HOME/ab-runs")   # per-checkout default: git config ab.runsDir /some/dir
RUNS_DIR=${RUNS_DIR/#\~/$HOME}   # a leading ~ in the config value means $HOME, so one checkout shared by two machines works
OUT="${AB_OUT:-$RUNS_DIR/$(date +%Y%m%d-%H%M%S)}"; mkdir -p "$OUT"
if command -v ast-grep >/dev/null 2>&1; then SG=ast-grep
elif command -v guix >/dev/null 2>&1; then SG="guix shell ast-grep -- ast-grep"
else echo "need ast-grep on PATH (or Guix)" >&2; exit 1; fi
SG_POLICY=$($SG --help 2>/dev/null | grep -q -- --custom-languages && echo "--custom-languages allow")   # ast-grep 0.50+ opt-in
SCAN="$SG scan $SG_POLICY -c $JAT/sgconfig.yml --filter ^lint-"
log() { printf '%s %s\n' "$(date '+%H:%M:%S')" "$*" | tee -a "$OUT/run.log"; }
lint_hits() { $SCAN "$1/src" "$1/test" 2>/dev/null | grep -c -E '^(warning|error)\[' || true; }

# Positive control: the scanner must see a known-bad snippet, or the numbers mean nothing.
ctrl=$(mktemp -d); printf 'struct Bad\n    data\n    value::Any\nend\n' > "$ctrl/bad.jl"
hits=$($SCAN "$ctrl" 2>/dev/null | grep -c -E '^(warning|error)\[' || true); rm -rf "$ctrl"
log "positive control: $hits lint hit(s) on a known-bad struct"; [ "$hits" -ge 1 ] || { log "ABORT: scanner saw nothing (did you run make dylib?)"; exit 1; }
log "tools: $(julia --version 2>&1 | head -1); claude $(claude --version 2>&1 | head -1); $(ast-grep --version 2>/dev/null || echo 'ast-grep via guix')"
if [ "${1:-}" = "--check" ]; then log "check only; results dir would be $OUT"; exit 0; fi
SRC=${1:?usage: ab.sh /path/to/a/julia/project (or --check)}

for side in bare tooled; do
  rm -rf "$OUT/$side"; git clone -q "$SRC" "$OUT/$side"
  rm -rf "$OUT/$side/.claude" "$OUT/$side/.agents" "$OUT/$side/.codex"   # host-specific agent hooks; removed on both sides alike
  git -C "$OUT/$side" config commit.gpgsign false   # throwaway clones: no signing prompts, 22 commits per run
  git -C "$OUT/$side" config user.name "ab" ; git -C "$OUT/$side" config user.email "ab@localhost"
  git -C "$OUT/$side" add -A && git -C "$OUT/$side" commit -q -m "ab: baseline ($side)" --allow-empty
done
julia --project="$JAT" -e 'using JuliaAgentTools; install_directives(ARGS[1]; overwrite=true)' "$OUT/tooled" >> "$OUT/run.log" 2>&1
git -C "$OUT/tooled" add -A && git -C "$OUT/tooled" commit -q -m "ab: directives installed"
for side in bare tooled; do (cd "$OUT/$side" && julia --project=. -e 'using Pkg; Pkg.instantiate()' >> "$OUT/run.log" 2>&1); done
base_bare=$(lint_hits "$OUT/bare"); base_tooled=$(lint_hits "$OUT/tooled")
log "baseline lint hits: bare=$base_bare tooled=$base_tooled"
printf 'side\ttask\tlint_delta\ttests\tfiles_changed\tagent_exit\tseconds\n' > "$OUT/scores.tsv"

i=0
while IFS= read -r task; do i=$((i+1))
  for side in bare tooled; do
    copy="$OUT/$side"; base=$([ "$side" = bare ] && echo "$base_bare" || echo "$base_tooled")
    git -C "$copy" checkout -q main && git -C "$copy" clean -fdq && git -C "$copy" checkout -q -b "task-$i"
    log "task $i $side: agent start"; t0=$(date +%s)
    prompt="In this Julia package: $task Put new code in src/ (a new file included from the main module is fine) and tests in test/. Keep the change small, then stop."
    # stdin from /dev/null: the agent must not see the rest of the task list
    (cd "$copy" && timeout 1200 env -u CLAUDECODE claude -p --permission-mode acceptEdits \
        --allowedTools "Edit,Write,Read,Glob,Grep,Bash(julia:*),Bash(make:*)" --max-turns 40 --output-format text \
        "$prompt" < /dev/null > "$OUT/log-$side-$i.txt" 2>&1); agent_exit=$?
    git -C "$copy" add -A; git -C "$copy" commit -q -m "task $i" --allow-empty
    files=$(git -C "$copy" diff --name-only main | wc -l | tr -d ' ')
    hits=$(lint_hits "$copy"); delta=$((hits - base))
    (cd "$copy" && timeout 900 julia --project=. -e 'using Pkg; Pkg.test()' > "$OUT/test-$side-$i.txt" 2>&1) && tests=pass || tests=FAIL
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$side" "$i" "$delta" "$tests" "$files" "$agent_exit" "$(( $(date +%s) - t0 ))" >> "$OUT/scores.tsv"
    log "task $i $side: lint_delta=$delta tests=$tests files=$files agent_exit=$agent_exit"
  done
done < "$TASKS"
log "done; results in $OUT"; column -t -s $'\t' "$OUT/scores.tsv" 2>/dev/null || cat "$OUT/scores.tsv"
