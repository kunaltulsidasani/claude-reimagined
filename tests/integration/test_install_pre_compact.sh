#!/usr/bin/env bash
# Integration tests for scripts/install_pre_compact.sh
# Overrides HOME to tmp — never touches real ~/.claude
set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "${TESTS_DIR}/.." && pwd)"
source "${TESTS_DIR}/lib/helpers.sh"

SCRIPT="${REPO_ROOT}/scripts/install_pre_compact.sh"

setup_tmp

fake_home() { echo "${TMPDIR_TEST}/home_$$_${RANDOM}"; }

# ── Skip flag ─────────────────────────────────────────────────────────────────

suite "install_pre_compact — --skip"

h=$(fake_home); mkdir -p "$h"
HOME="$h" BOOTSTRAP_SKIP="pre-compact" BOOTSTRAP_YES=1 \
  BOOTSTRAP_LOG_DIR="${h}/logs" BOOTSTRAP_DRY_RUN=0 BOOTSTRAP_FORCE=0 \
  bash "$SCRIPT" >/dev/null 2>&1

assert_file_not_exists "skip: hook file not copied" "${h}/.claude/hooks/pre-compact.sh"

tsv="${h}/logs/results.tsv"
assert_file_exists "skip: results.tsv written" "$tsv"
assert_contains "skip: SKIPPED recorded" "SKIPPED" "$(cat "$tsv")"

# ── Dry-run ───────────────────────────────────────────────────────────────────

suite "install_pre_compact — dry-run"

h=$(fake_home); mkdir -p "$h"
HOME="$h" BOOTSTRAP_SKIP="" BOOTSTRAP_YES=1 \
  BOOTSTRAP_LOG_DIR="${h}/logs" BOOTSTRAP_DRY_RUN=1 BOOTSTRAP_FORCE=0 \
  bash "$SCRIPT" >/dev/null 2>&1

assert_file_not_exists "dry-run: hook file not copied"   "${h}/.claude/hooks/pre-compact.sh"
assert_file_not_exists "dry-run: settings.json not written" "${h}/.claude/settings.json"

# ── Normal install ────────────────────────────────────────────────────────────

suite "install_pre_compact — normal install"

h=$(fake_home); mkdir -p "$h"
HOME="$h" BOOTSTRAP_SKIP="" BOOTSTRAP_YES=1 \
  BOOTSTRAP_LOG_DIR="${h}/logs" BOOTSTRAP_DRY_RUN=0 BOOTSTRAP_FORCE=0 \
  bash "$SCRIPT" >/dev/null 2>&1

dest="${h}/.claude/hooks/pre-compact.sh"
assert_file_exists  "hook file copied"      "$dest"
assert_executable   "hook file executable"  "$dest"

settings="${h}/.claude/settings.json"
assert_file_exists  "settings.json created" "$settings"

content=$(cat "$settings")
assert_contains "PreCompact registered" "PreCompact" "$content"
assert_contains "hook path in command"  "pre-compact.sh" "$content"

# Valid JSON
python3 -c "import sys,json; json.load(open('${settings}'))" 2>/dev/null \
  && pass "settings.json is valid JSON" \
  || fail "settings.json is valid JSON"

assert_contains "result OK" "OK" "$(cat "${h}/logs/results.tsv")"

# ── Already installed — no --force skips ─────────────────────────────────────

suite "install_pre_compact — already installed, no --force"

h=$(fake_home); mkdir -p "${h}/.claude/hooks"
cp "${REPO_ROOT}/hooks/pre-compact.sh" "${h}/.claude/hooks/pre-compact.sh"
echo '{"hooks":{"PreCompact":[{"hooks":[{"type":"command","command":"bash \"'"${h}"'/.claude/hooks/pre-compact.sh\""}]}]}}' \
  > "${h}/.claude/settings.json"

HOME="$h" BOOTSTRAP_SKIP="" BOOTSTRAP_YES=1 \
  BOOTSTRAP_LOG_DIR="${h}/logs" BOOTSTRAP_DRY_RUN=0 BOOTSTRAP_FORCE=0 \
  bash "$SCRIPT" >/dev/null 2>&1

assert_contains "already-installed: SKIPPED" "SKIPPED" "$(cat "${h}/logs/results.tsv")"
# No backup created (file not overwritten)
bak_count=$(find "${h}/.claude" -name "settings.json.bak.*" | wc -l | tr -d ' ')
assert_eq "already-installed: no backup" "0" "$bak_count"

# ── --force reinstalls ────────────────────────────────────────────────────────

suite "install_pre_compact — --force reinstalls"

h=$(fake_home); mkdir -p "${h}/.claude/hooks"
cp "${REPO_ROOT}/hooks/pre-compact.sh" "${h}/.claude/hooks/pre-compact.sh"
echo '{"hooks":{"PreCompact":[{"hooks":[{"type":"command","command":"bash \"'"${h}"'/.claude/hooks/pre-compact.sh\""}]}]}}' \
  > "${h}/.claude/settings.json"

HOME="$h" BOOTSTRAP_SKIP="" BOOTSTRAP_YES=1 \
  BOOTSTRAP_LOG_DIR="${h}/logs" BOOTSTRAP_DRY_RUN=0 BOOTSTRAP_FORCE=1 \
  bash "$SCRIPT" >/dev/null 2>&1

assert_contains "force: OK recorded" "OK" "$(cat "${h}/logs/results.tsv")"
bak_count=$(find "${h}/.claude" -name "settings.json.bak.*" | wc -l | tr -d ' ')
assert_eq "force: backup created" "1" "$bak_count"

# ── Idempotent: re-running does not duplicate PreCompact entry ────────────────

suite "install_pre_compact — idempotent registration"

h=$(fake_home); mkdir -p "$h"

# Run twice
HOME="$h" BOOTSTRAP_SKIP="" BOOTSTRAP_YES=1 \
  BOOTSTRAP_LOG_DIR="${h}/logs" BOOTSTRAP_DRY_RUN=0 BOOTSTRAP_FORCE=0 \
  bash "$SCRIPT" >/dev/null 2>&1

HOME="$h" BOOTSTRAP_SKIP="" BOOTSTRAP_YES=1 \
  BOOTSTRAP_LOG_DIR="${h}/logs2" BOOTSTRAP_DRY_RUN=0 BOOTSTRAP_FORCE=1 \
  bash "$SCRIPT" >/dev/null 2>&1

count=$(python3 -c "
import json
data = json.load(open('${h}/.claude/settings.json'))
entries = data.get('hooks', {}).get('PreCompact', [])
cmds = [h['command'] for e in entries for h in e.get('hooks', [])]
print(sum(1 for c in cmds if 'pre-compact' in c))
" 2>/dev/null)
assert_eq "PreCompact not duplicated after two installs" "1" "$count"

summary
