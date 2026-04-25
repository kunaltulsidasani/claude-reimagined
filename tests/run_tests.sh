#!/usr/bin/env bash
# Test runner — discovers and runs all test_*.sh files under tests/
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${TESTS_DIR}/.." && pwd)"

_GRN='\033[0;32m'
_RED='\033[0;31m'
_YLW='\033[1;33m'
_BLD='\033[1m'
_RST='\033[0m'

_total_pass=0
_total_fail=0
_total_skip=0
_suite_results=()

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS] [FILTER]

Options:
  --unit          Run only unit tests
  --integration   Run only integration tests
  --help          Show this help

FILTER  Substring match against test file name (e.g. "router" or "common")

Examples:
  ./tests/run_tests.sh
  ./tests/run_tests.sh --unit
  ./tests/run_tests.sh router
  ./tests/run_tests.sh --integration settings
EOF
}

_mode="all"
_filter=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --unit)        _mode="unit";        shift ;;
    --integration) _mode="integration"; shift ;;
    --help|-h)     usage; exit 0 ;;
    -*)            echo "Unknown flag: $1"; usage; exit 1 ;;
    *)             _filter="$1"; shift ;;
  esac
done

# Collect test files
_files=()
case "$_mode" in
  unit)        mapfile -t _files < <(find "${TESTS_DIR}/unit"        -name "test_*.sh" | sort) ;;
  integration) mapfile -t _files < <(find "${TESTS_DIR}/integration" -name "test_*.sh" | sort) ;;
  all)         mapfile -t _files < <(find "${TESTS_DIR}" -name "test_*.sh" | sort) ;;
esac

if [[ -n "$_filter" ]]; then
  _filtered=()
  for f in "${_files[@]}"; do
    [[ "$(basename "$f")" == *"$_filter"* ]] && _filtered+=("$f")
  done
  _files=("${_filtered[@]}")
fi

if [[ "${#_files[@]}" -eq 0 ]]; then
  echo "No test files found."
  exit 1
fi

printf "\n${_BLD}━━━ claude-reimagined test suite ━━━━━━━━━━━━━━━━━━━━━${_RST}\n"
printf "  Repo: %s\n" "$REPO_ROOT"
printf "  Mode: %s\n" "$_mode"
[[ -n "$_filter" ]] && printf "  Filter: %s\n" "$_filter"
printf "  Files: %d\n" "${#_files[@]}"

for file in "${_files[@]}"; do
  rel="${file#${TESTS_DIR}/}"
  printf "\n${_BLD}▶ %s${_RST}\n" "$rel"

  # Run each test file in a subshell so state doesn't leak
  output=$(bash "$file" 2>&1) || true
  printf '%s\n' "$output"

  # Parse pass/fail/skip from summary line printed by the file
  p=$(printf '%s' "$output" | grep -oE '[0-9]+ passed'  | grep -oE '[0-9]+' || echo 0)
  f=$(printf '%s' "$output" | grep -oE '[0-9]+ failed'  | grep -oE '[0-9]+' || echo 0)
  s=$(printf '%s' "$output" | grep -oE '[0-9]+ skipped' | grep -oE '[0-9]+' || echo 0)

  _total_pass=$(( _total_pass + p ))
  _total_fail=$(( _total_fail + f ))
  _total_skip=$(( _total_skip + s ))

  if [[ "$f" -gt 0 ]]; then
    _suite_results+=("${_RED}FAIL${_RST}  $rel")
  else
    _suite_results+=("${_GRN}PASS${_RST}  $rel")
  fi
done

printf "\n${_BLD}━━━ Suite Summary ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${_RST}\n"
for r in "${_suite_results[@]}"; do
  printf "  %b\n" "$r"
done

printf "\n  ${_GRN}%d passed${_RST}  ${_RED}%d failed${_RST}  ${_YLW}%d skipped${_RST}\n\n" \
  "$_total_pass" "$_total_fail" "$_total_skip"

[[ "$_total_fail" -eq 0 ]]
