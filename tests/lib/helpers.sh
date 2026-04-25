#!/usr/bin/env bash
# Test helpers — assert functions, tmp dir lifecycle, counters

_PASS=0
_FAIL=0
_SKIP=0
_CURRENT_SUITE=""

_GRN='\033[0;32m'
_RED='\033[0;31m'
_YLW='\033[1;33m'
_DIM='\033[2m'
_RST='\033[0m'
_BLD='\033[1m'

suite() { _CURRENT_SUITE="$1"; printf "\n${_BLD}  %s${_RST}\n" "$1"; }

pass() { printf "  ${_GRN}✓${_RST} ${_DIM}%s${_RST}\n" "$1"; (( _PASS += 1 )); }
fail() { printf "  ${_RED}✗${_RST} %s\n" "$1"; (( _FAIL += 1 )); }
skip() { printf "  ${_YLW}–${_RST} ${_DIM}%s (skipped)${_RST}\n" "$1"; (( _SKIP += 1 )); }

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    pass "$label"
  else
    fail "$label"
    printf "      expected: %s\n" "$expected"
    printf "      actual:   %s\n" "$actual"
  fi
}

assert_contains() {
  local label="$1" needle="$2" haystack="$3"
  if printf '%s' "$haystack" | grep -qF -- "$needle"; then
    pass "$label"
  else
    fail "$label"
    printf "      expected to contain: %s\n" "$needle"
    printf "      actual output:\n"
    printf '%s\n' "$haystack" | head -10 | sed 's/^/        /'
  fi
}

assert_not_contains() {
  local label="$1" needle="$2" haystack="$3"
  if ! printf '%s' "$haystack" | grep -qF -- "$needle"; then
    pass "$label"
  else
    fail "$label"
    printf "      expected NOT to contain: %s\n" "$needle"
  fi
}

assert_exit_ok()   { local label="$1" code="$2"; [[ "$code" -eq 0 ]]   && pass "$label" || { fail "$label"; printf "      exit code: %d\n" "$code"; }; }
assert_exit_fail() { local label="$1" code="$2"; [[ "$code" -ne 0 ]]   && pass "$label" || { fail "$label"; printf "      expected non-zero exit\n"; }; }

assert_file_exists()     { local label="$1" path="$2"; [[ -f "$path" ]] && pass "$label" || { fail "$label"; printf "      file not found: %s\n" "$path"; }; }
assert_file_not_exists() { local label="$1" path="$2"; [[ ! -f "$path" ]] && pass "$label" || { fail "$label"; printf "      file should not exist: %s\n" "$path"; }; }
assert_executable()      { local label="$1" path="$2"; [[ -x "$path" ]] && pass "$label" || { fail "$label"; printf "      not executable: %s\n" "$path"; }; }

# Create a temp dir, set TMPDIR_TEST, register cleanup on EXIT
setup_tmp() {
  TMPDIR_TEST="$(mktemp -d)"
  trap 'rm -rf "${TMPDIR_TEST}"' EXIT
}

# Print final summary and exit with appropriate code
summary() {
  local total=$(( _PASS + _FAIL + _SKIP ))
  printf "\n${_BLD}━━━ Results ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${_RST}\n"
  printf "  ${_GRN}%d passed${_RST}  ${_RED}%d failed${_RST}  ${_YLW}%d skipped${_RST}  (total: %d)\n\n" \
    "$_PASS" "$_FAIL" "$_SKIP" "$total"
  [[ "$_FAIL" -eq 0 ]]
}
