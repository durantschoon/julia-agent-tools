#!/usr/bin/env bash
# check.sh --- score Julia files against the two struct-field lint rules.
#
# Usage:
#   check.sh PATH...       Score each file or directory of model-written Julia.
#                          Exit status 0 when nothing is flagged, 1 when
#                          something is, 2 when nothing could be scored (a
#                          path is missing, or the scan is not working).
#   check.sh --self-test   Confirm the checker itself still works: the flagged
#                          control gets exactly two hits, the clean reference
#                          gets none, and a broken setup is refused.
#
# A scan that cannot run (no grammar, missing rules) prints no hits, which
# looks the same as clean code. So every scoring run first checks that the
# flagged control still gets its two hits, and stops with status 2 if not.
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

# Stop with status 2 unless the flagged control still gets its two hits.
require_working_scan() {
    local hits
    hits="$(count_hits "${PROBE_DIR}/field_checks_demo.jl" 2>/dev/null)"
    if [[ "${hits}" -ne 2 ]]; then
        echo "check.sh: the scan is not working: the flagged control got ${hits} hits, expected 2." >&2
        echo "Run 'make dylib' at the repository root, or fix SG_CONFIG (${SG_CONFIG}), then retry." >&2
        exit 2
    fi
}

# Fail unless a scoring run with an unusable configuration is refused (status 2).
expect_broken_setup_refused() {
    local refusal=0
    SG_CONFIG="${PROBE_DIR}/no-such-sgconfig.yml" "${BASH_SOURCE[0]}" \
        "${PROBE_DIR}/field_checks_demo.jl" >/dev/null 2>&1 || refusal=$?
    if [[ "${refusal}" -eq 2 ]]; then
        echo "ok    a broken setup is refused (status 2)"
    else
        echo "FAIL  a broken setup was scored (status ${refusal}, expected 2)"
        return 1
    fi
}

if [[ $# -eq 0 || "$1" == "-h" || "$1" == "--help" ]]; then
    sed -n '2,18p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 0
fi

if [[ "$1" == "--self-test" ]]; then
    status=0
    expect_hits "${PROBE_DIR}/field_checks_demo.jl" 2 || status=1
    expect_hits "${PROBE_DIR}/particles_2d.jl" 0 || status=1
    expect_broken_setup_refused || status=1
    exit "${status}"
fi

require_working_scan

status=0
for target in "$@"; do
    if [[ ! -e "${target}" ]]; then
        echo "MISSING  ${target}" >&2
        status=2
        continue
    fi
    report "${target}" || { [[ "${status}" -eq 2 ]] || status=1; }
done
exit "${status}"
