#!/usr/bin/env bash
# Integration tests for scripts/migrate_settings.sh
# Overrides HOME to tmp — never touches real ~/.claude
set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "${TESTS_DIR}/.." && pwd)"
source "${TESTS_DIR}/lib/helpers.sh"

SCRIPT="${REPO_ROOT}/scripts/migrate_settings.sh"

if ! command -v python3 >/dev/null 2>&1; then
    skip "python3 not found — skipping migrate_settings tests"
    summary; exit 0
fi

setup_tmp

fake_home() { echo "${TMPDIR_TEST}/home_$$_${RANDOM}"; }

# ── Skip flag ─────────────────────────────────────────────────────────────────

suite "migrate_settings — --skip"

h=$(fake_home); mkdir -p "${h}/.claude"
echo 'FOO="bar"' > "${h}/.claude/settings.sh"

HOME="$h" BOOTSTRAP_SKIP="settings" BOOTSTRAP_YES=1 \
  BOOTSTRAP_LOG_DIR="${h}/logs" BOOTSTRAP_DRY_RUN=0 BOOTSTRAP_FORCE=0 \
  bash "$SCRIPT" >/dev/null 2>&1

assert_file_not_exists "skip: settings.json not written" "${h}/.claude/settings.json"
assert_contains "skip: SKIPPED recorded" "SKIPPED" "$(cat "${h}/logs/results.tsv")"

# ── No source file found ──────────────────────────────────────────────────────

suite "migrate_settings — no source settings.sh found"

h=$(fake_home); mkdir -p "$h"
HOME="$h" BOOTSTRAP_SKIP="" BOOTSTRAP_YES=1 \
  BOOTSTRAP_LOG_DIR="${h}/logs" BOOTSTRAP_DRY_RUN=0 BOOTSTRAP_FORCE=0 \
  bash "$SCRIPT" >/dev/null 2>&1

assert_file_not_exists "no-source: settings.json not written" "${h}/.claude/settings.json"
assert_contains "no-source: SKIPPED recorded" "SKIPPED" "$(cat "${h}/logs/results.tsv")"

# ── Dry-run with source present ───────────────────────────────────────────────

suite "migrate_settings — dry-run"

h=$(fake_home); mkdir -p "${h}/.claude"
printf 'FOO="hello"\nBAR="world"\n' > "${h}/.claude/settings.sh"

out="$(HOME="$h" BOOTSTRAP_SKIP="" BOOTSTRAP_YES=1 \
  BOOTSTRAP_LOG_DIR="${h}/logs" BOOTSTRAP_DRY_RUN=1 BOOTSTRAP_FORCE=0 \
  bash "$SCRIPT" 2>&1)"

assert_file_not_exists "dry-run: settings.json not written" "${h}/.claude/settings.json"
assert_contains "dry-run: prints Would" "Would" "$out"
assert_contains "dry-run: lists FOO"   "FOO"    "$out"
assert_contains "dry-run: lists BAR"   "BAR"    "$out"

# ── Normal migration: KEY=VALUE pairs merged into settings.json ───────────────

suite "migrate_settings — migrates KEY=VALUE into settings.json"

h=$(fake_home); mkdir -p "${h}/.claude"
printf 'SIMPLE_KEY="hello"\nANOTHER="world"\n' > "${h}/.claude/settings.sh"

HOME="$h" BOOTSTRAP_SKIP="" BOOTSTRAP_YES=1 \
  BOOTSTRAP_LOG_DIR="${h}/logs" BOOTSTRAP_DRY_RUN=0 BOOTSTRAP_FORCE=0 \
  bash "$SCRIPT" >/dev/null 2>&1

assert_file_exists "settings.json created" "${h}/.claude/settings.json"

python3 -c "import json; json.load(open('${h}/.claude/settings.json'))" 2>/dev/null \
  && pass "settings.json is valid JSON" \
  || fail "settings.json is valid JSON"

content="$(cat "${h}/.claude/settings.json")"
assert_contains "SIMPLE_KEY present" "SIMPLE_KEY" "$content"
assert_contains "ANOTHER present"    "ANOTHER"    "$content"
assert_contains "hello value present" "hello"     "$content"
assert_contains "world value present" "world"     "$content"

assert_contains "OK recorded" "OK" "$(cat "${h}/logs/results.tsv")"

# Original settings.sh preserved as .migrated copy
assert_file_exists "migrated copy created" "${h}/.claude/settings.sh.migrated"

# ── Merges into existing settings.json without clobbering existing keys ───────

suite "migrate_settings — merge preserves existing settings.json keys"

h=$(fake_home); mkdir -p "${h}/.claude"
echo '{"existingKey":"existingVal"}' > "${h}/.claude/settings.json"
printf 'NEW_KEY="newval"\n' > "${h}/.claude/settings.sh"

HOME="$h" BOOTSTRAP_SKIP="" BOOTSTRAP_YES=1 \
  BOOTSTRAP_LOG_DIR="${h}/logs" BOOTSTRAP_DRY_RUN=0 BOOTSTRAP_FORCE=0 \
  bash "$SCRIPT" >/dev/null 2>&1

content="$(cat "${h}/.claude/settings.json")"
assert_contains "existing key preserved" "existingKey"  "$content"
assert_contains "existing val preserved" "existingVal"  "$content"
assert_contains "new key merged in"      "NEW_KEY"       "$content"
assert_contains "new val merged in"      "newval"        "$content"

bak_count=$(find "${h}/.claude" -name "settings.json.bak.*" 2>/dev/null | wc -l | tr -d ' ')
assert_eq "backup of existing settings.json created" "1" "$bak_count"

# ── Complex/unsafe lines are skipped, simple ones still migrate ──────────────

suite "migrate_settings — complex assignments skipped, simple ones proceed"

h=$(fake_home); mkdir -p "${h}/.claude"
printf 'SAFE_KEY="safe"\nCOMPLEX_KEY=$(echo bad)\n' > "${h}/.claude/settings.sh"

HOME="$h" BOOTSTRAP_SKIP="" BOOTSTRAP_YES=1 \
  BOOTSTRAP_LOG_DIR="${h}/logs" BOOTSTRAP_DRY_RUN=0 BOOTSTRAP_FORCE=0 \
  bash "$SCRIPT" >/dev/null 2>&1

content="$(cat "${h}/.claude/settings.json")"
assert_contains     "safe key migrated"          "SAFE_KEY"     "$content"
assert_not_contains "complex key not migrated"   "COMPLEX_KEY"  "$content"

summary
