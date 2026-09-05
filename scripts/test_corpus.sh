#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SG_CONFIG="${ROOT_DIR}/sgconfig.yml"
CTAGS_OPT="${ROOT_DIR}/ctags.d/julia.ctags"
TMP_CORPUS="/tmp/julia_corpus_test"

echo "========================================================"
echo " Starting Julia Agent Tools Corpus Stress-Testing Suite "
echo "========================================================"

mkdir -p "${TMP_CORPUS}"

# Target repositories: local repositories first
TARGET_DIRS=()

if [[ -d "${ROOT_DIR}/../gafro-julia/src" ]]; then
    echo "Found local gafro-julia repository."
    TARGET_DIRS+=("${ROOT_DIR}/../gafro-julia/src")
fi

# Clone StaticArrays.jl shallow clone for heavy metaprogramming coverage if git remote is reachable
if [[ ! -d "${TMP_CORPUS}/StaticArrays.jl" ]]; then
    echo "Fetching StaticArrays.jl for corpus stress testing..."
    git clone --depth 1 https://github.com/JuliaArrays/StaticArrays.jl.git "${TMP_CORPUS}/StaticArrays.jl" 2>/dev/null || echo "Warning: network clone skipped; continuing with local corpus."
fi

if [[ -d "${TMP_CORPUS}/StaticArrays.jl/src" ]]; then
    TARGET_DIRS+=("${TMP_CORPUS}/StaticArrays.jl/src")
fi

if [[ ${#TARGET_DIRS[@]} -eq 0 ]]; then
    echo "No target repositories found for corpus testing. Falling back to test/fixtures."
    TARGET_DIRS+=("${ROOT_DIR}/test/fixtures")
fi

TOTAL_FILES=0
for DIR in "${TARGET_DIRS[@]}"; do
    NUM=$(find "${DIR}" -name "*.jl" | wc -l | tr -d ' ')
    TOTAL_FILES=$((TOTAL_FILES + NUM))
    echo "Target corpus: ${DIR} (${NUM} .jl files)"
done
echo "Total corpus size: ${TOTAL_FILES} Julia source files."

echo ""
echo "==> 1. Running ast-grep scan across corpus..."
AST_START=$(date +%s)
for DIR in "${TARGET_DIRS[@]}"; do
    echo "  Scanning ${DIR}..."
    ast-grep scan -c "${SG_CONFIG}" "${DIR}" > /dev/null
done
AST_END=$(date +%s)
echo "  ✓ ast-grep completed with 0 errors in $((AST_END - AST_START))s."

echo ""
echo "==> 2. Running Universal Ctags with Julia optlib across corpus..."
CTAGS_START=$(date +%s)
TAGS_OUT="${TMP_CORPUS}/tags_corpus"
for DIR in "${TARGET_DIRS[@]}"; do
    echo "  Tagging ${DIR}..."
    ctags --options="${CTAGS_OPT}" -f "${TAGS_OUT}" -R "${DIR}"
done
CTAGS_END=$(date +%s)
TAG_COUNT=$(wc -l < "${TAGS_OUT}" | tr -d ' ')
echo "  ✓ Universal Ctags completed in $((CTAGS_END - CTAGS_START))s: generated ${TAG_COUNT} symbol tags."

echo ""
echo "==> 3. Sampling detected AST constructs in corpus..."
echo -n "  Total struct definitions: "
ast-grep run -c "${SG_CONFIG}" -k struct_definition "${TARGET_DIRS[@]}" --json=compact | grep -o '\"text\"' | wc -l | tr -d ' ' || true

echo -n "  Total function definitions: "
ast-grep run -c "${SG_CONFIG}" -k function_definition "${TARGET_DIRS[@]}" --json=compact | grep -o '\"text\"' | wc -l | tr -d ' ' || true

echo -n "  Total parametric methods (where): "
ast-grep run -c "${SG_CONFIG}" -k where_expression "${TARGET_DIRS[@]}" --json=compact | grep -o '\"text\"' | wc -l | tr -d ' ' || true

echo ""
echo "========================================================"
echo " Corpus Stress-Testing Passed Successfully!            "
echo "========================================================"
