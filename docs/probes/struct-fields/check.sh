#!/usr/bin/env bash
# check.sh --- score Julia files against the two struct-field lint rules.
#
# Usage:
#   check.sh PATH...       Score each file or directory of model-written Julia.
#                          Exit status 0 when nothing is flagged, 1 otherwise.
#   check.sh --self-test   Confirm the checker itself still works: the flagged
#                          control gets exactly two hits and the clean
#                          reference gets none.
#
# Needs ast-grep and the Julia grammar (`make dylib` at the repository root).
# SG_CONFIG overrides the ast-grep configuration file.
set -euo pipefail

PROBE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${PROBE_DIR}/../../.." && pwd)"
SG_CONFIG="${SG_CONFIG:-${ROOT_DIR}/sgconfig.yml}"
FIELD_RULES='lint-(untyped|abstract)-struct-field'

# ast-grep 0.50+ needs an explicit opt-in for native custom languages; older
# versions reject the option.
SG_POLICY=$(ast-grep --help 2>/dev/null | grep -q -- --custom-languages && echo "--custom-languages allow" || true)

# Run the two field rules on one path, in the given ast-grep output style.
scan_fields() {
    local target="$1"; shift
    ast-grep scan ${SG_POLICY} -c "${SG_CONFIG}" --filter "${FIELD_RULES}" "$@" "${target}"
}

# Print the number of hits for one path (one JSON object per line, one per hit).
count_hits() {
    scan_fields "$1" --json=stream | grep -c '"ruleId"' || true
}

# Print a PASS or FLAGGED line for one path, then the hits themselves.
report() {
    local target="$1" hits
    hits="$(count_hits "${target}")"
    if [[ "${hits}" -eq 0 ]]; then
        echo "PASS     ${target} (0 hits)"
    else
        echo "FLAGGED  ${target} (${hits} hits)"
        scan_fields "${target}" --report-style=short || true
    fi
    [[ "${hits}" -eq 0 ]]
}

# Fail unless one path has exactly the expected number of hits.
expect_hits() {
    local target="$1" expected="$2" hits
    hits="$(count_hits "${target}")"
    if [[ "${hits}" -eq "${expected}" ]]; then
        echo "ok    ${target}: ${hits} hits"
    else
        echo "FAIL  ${target}: expected ${expected} hits, found ${hits}"
        return 1
    fi
}

if [[ $# -eq 0 || "$1" == "-h" || "$1" == "--help" ]]; then
    sed -n '2,13p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 0
fi

if [[ "$1" == "--self-test" ]]; then
    status=0
    expect_hits "${PROBE_DIR}/field_checks_demo.jl" 2 || status=1
    expect_hits "${PROBE_DIR}/particles_2d.jl" 0 || status=1
    exit "${status}"
fi

status=0
for target in "$@"; do
    report "${target}" || status=1
done
exit "${status}"
