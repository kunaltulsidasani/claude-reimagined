#!/usr/bin/env bash
# Integration tests for scripts/configure_settings.sh
# Overrides HOME to a tmp dir — never touches real ~/.claude
set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "${TESTS_DIR}/.." && pwd)"
source "${TESTS_DIR}/lib/helpers.sh"

SCRIPT="${REPO_ROOT}/scripts/configure_settings.sh"

setup_tmp

fake_home() { echo "${TMPDIR_TEST}/home_$$_${RANDOM}"; }

# ── Skip flag ─────────────────────────────────────────────────────────────────

suite "configure_settings — --skip"

h=$(fake_home); mkdir -p "$h"
HOME="$h" BOOTSTRAP_SKIP="settings-config" BOOTSTRAP_YES=1 \
  BOOTSTRAP_LOG_DIR="${h}/logs" BOOTSTRAP_DRY_RUN=0 BOOTSTRAP_FORCE=0 \
  bash "$SCRIPT" >/dev/null 2>&1

assert_file_not_exists "skip: settings.json not written" "${h}/.claude/settings.json"

# ── Already exists without --force ───────────────────────────────────────────

suite "configure_settings — already exists, no --force"

h=$(fake_home); mkdir -p "${h}/.claude"
echo '{"existing":true}' > "${h}/.claude/settings.json"

HOME="$h" BOOTSTRAP_SKIP="" BOOTSTRAP_YES=1 \
  BOOTSTRAP_LOG_DIR="${h}/logs" BOOTSTRAP_DRY_RUN=0 BOOTSTRAP_FORCE=0 \
  bash "$SCRIPT" >/dev/null 2>&1

content=$(cat "${h}/.claude/settings.json")
assert_contains "no-force: existing file unchanged" "existing" "$content"

# ── Dry-run: no file written ──────────────────────────────────────────────────

suite "configure_settings — dry-run"

h=$(fake_home); mkdir -p "$h"
HOME="$h" BOOTSTRAP_SKIP="" BOOTSTRAP_YES=1 \
  BOOTSTRAP_LOG_DIR="${h}/logs" BOOTSTRAP_DRY_RUN=1 BOOTSTRAP_FORCE=0 \
  bash "$SCRIPT" >/dev/null 2>&1

assert_file_not_exists "dry-run: settings.json not written" "${h}/.claude/settings.json"

# ── Normal install: __HOME__ substituted ─────────────────────────────────────

suite "configure_settings — installs with __HOME__ substitution"

h=$(fake_home); mkdir -p "$h"
HOME="$h" BOOTSTRAP_SKIP="" BOOTSTRAP_YES=1 \
  BOOTSTRAP_LOG_DIR="${h}/logs" BOOTSTRAP_DRY_RUN=0 BOOTSTRAP_FORCE=0 \
  bash "$SCRIPT" >/dev/null 2>&1

assert_file_exists "settings.json created" "${h}/.claude/settings.json"

content=$(cat "${h}/.claude/settings.json")
assert_not_contains "__HOME__ not in output"  "__HOME__" "$content"
assert_contains     "home path substituted"   "$h"       "$content"

# Valid JSON
python3 -c "import sys,json; json.load(open('${h}/.claude/settings.json'))" 2>/dev/null \
  && pass "settings.json is valid JSON" \
  || fail "settings.json is valid JSON"

# ── --force overwrites existing ───────────────────────────────────────────────

suite "configure_settings — --force overwrites existing"

h=$(fake_home); mkdir -p "${h}/.claude"
echo '{"old":true}' > "${h}/.claude/settings.json"

HOME="$h" BOOTSTRAP_SKIP="" BOOTSTRAP_YES=1 \
  BOOTSTRAP_LOG_DIR="${h}/logs" BOOTSTRAP_DRY_RUN=0 BOOTSTRAP_FORCE=1 \
  bash "$SCRIPT" >/dev/null 2>&1

content=$(cat "${h}/.claude/settings.json")
assert_not_contains "force: old content gone"  '"old"'   "$content"
assert_contains     "force: new content present" "$h"    "$content"

# Backup created
bak_count=$(find "${h}/.claude" -name "settings.json.bak.*" | wc -l | tr -d ' ')
assert_eq "force: backup created" "1" "$bak_count"

# ── results.tsv written ───────────────────────────────────────────────────────

suite "configure_settings — records result"

h=$(fake_home); mkdir -p "$h"
HOME="$h" BOOTSTRAP_SKIP="" BOOTSTRAP_YES=1 \
  BOOTSTRAP_LOG_DIR="${h}/logs" BOOTSTRAP_DRY_RUN=0 BOOTSTRAP_FORCE=0 \
  bash "$SCRIPT" >/dev/null 2>&1

assert_file_exists "results.tsv written" "${h}/logs/results.tsv"
assert_contains "result is OK" "OK" "$(cat "${h}/logs/results.tsv")"

summary
