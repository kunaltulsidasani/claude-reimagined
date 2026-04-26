#!/usr/bin/env bash
# Integration tests for scripts/install_statusline.sh
# Overrides HOME to tmp — never touches real ~/.claude
set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "${TESTS_DIR}/.." && pwd)"
source "${TESTS_DIR}/lib/helpers.sh"

SCRIPT="${REPO_ROOT}/scripts/install_statusline.sh"
SRC_STATUSLINE="${REPO_ROOT}/statusline.sh"

if [[ ! -f "${SRC_STATUSLINE}" ]]; then
    skip "statusline.sh not found at repo root — skipping"
    summary; exit 0
fi

if ! command -v python3 >/dev/null 2>&1; then
    skip "python3 not found — skipping install_statusline tests"
    summary; exit 0
fi

setup_tmp

fake_home() { echo "${TMPDIR_TEST}/home_$$_${RANDOM}"; }

# ── Skip flag ─────────────────────────────────────────────────────────────────

suite "install_statusline — --skip"

h=$(fake_home); mkdir -p "$h"
HOME="$h" BOOTSTRAP_SKIP="statusline" BOOTSTRAP_YES=1 \
  BOOTSTRAP_LOG_DIR="${h}/logs" BOOTSTRAP_DRY_RUN=0 BOOTSTRAP_FORCE=0 \
  bash "$SCRIPT" >/dev/null 2>&1

assert_file_not_exists "skip: statusline.sh not copied" "${h}/.claude/statusline.sh"
assert_contains "skip: SKIPPED recorded" "SKIPPED" "$(cat "${h}/logs/results.tsv")"

# ── Dry-run ───────────────────────────────────────────────────────────────────

suite "install_statusline — dry-run"

h=$(fake_home); mkdir -p "$h"
out="$(HOME="$h" BOOTSTRAP_SKIP="" BOOTSTRAP_YES=1 \
  BOOTSTRAP_LOG_DIR="${h}/logs" BOOTSTRAP_DRY_RUN=1 BOOTSTRAP_FORCE=0 \
  bash "$SCRIPT" 2>&1)"

assert_file_not_exists "dry-run: statusline.sh not copied"    "${h}/.claude/statusline.sh"
assert_file_not_exists "dry-run: settings.json not created"   "${h}/.claude/settings.json"
assert_contains "dry-run: prints Would" "Would" "$out"

# ── Fresh install ─────────────────────────────────────────────────────────────

suite "install_statusline — fresh install"

h=$(fake_home); mkdir -p "$h"
HOME="$h" BOOTSTRAP_SKIP="" BOOTSTRAP_YES=1 \
  BOOTSTRAP_LOG_DIR="${h}/logs" BOOTSTRAP_DRY_RUN=0 BOOTSTRAP_FORCE=0 \
  bash "$SCRIPT" >/dev/null 2>&1

dest="${h}/.claude/statusline.sh"
assert_file_exists  "statusline.sh copied"      "$dest"
assert_executable   "statusline.sh executable"  "$dest"

settings="${h}/.claude/settings.json"
assert_file_exists  "settings.json created"     "$settings"

content="$(cat "$settings")"
assert_contains "statusLine key present"         "statusLine"      "$content"
assert_contains "statusLine path points to dest" "statusline.sh"   "$content"

python3 -c "import json; json.load(open('${settings}'))" 2>/dev/null \
  && pass "settings.json is valid JSON" \
  || fail "settings.json is valid JSON"

assert_contains "OK recorded" "OK" "$(cat "${h}/logs/results.tsv")"

# ── statusLine value is the actual dest path ──────────────────────────────────

suite "install_statusline — statusLine value matches dest path"

h=$(fake_home); mkdir -p "$h"
HOME="$h" BOOTSTRAP_SKIP="" BOOTSTRAP_YES=1 \
  BOOTSTRAP_LOG_DIR="${h}/logs" BOOTSTRAP_DRY_RUN=0 BOOTSTRAP_FORCE=0 \
  bash "$SCRIPT" >/dev/null 2>&1

statusline_val="$(python3 -c "import json; d=json.load(open('${h}/.claude/settings.json')); print(d.get('statusLine',''))" 2>/dev/null)"
assert_eq "statusLine path value" "${h}/.claude/statusline.sh" "$statusline_val"

# ── Backup on re-run with existing settings.json ─────────────────────────────

suite "install_statusline — backup created when settings.json already exists"

h=$(fake_home); mkdir -p "${h}/.claude"
echo '{"existing":true}' > "${h}/.claude/settings.json"

HOME="$h" BOOTSTRAP_SKIP="" BOOTSTRAP_YES=1 \
  BOOTSTRAP_LOG_DIR="${h}/logs" BOOTSTRAP_DRY_RUN=0 BOOTSTRAP_FORCE=0 \
  bash "$SCRIPT" >/dev/null 2>&1

bak_count=$(find "${h}/.claude" -name "settings.json.bak.*" 2>/dev/null | wc -l | tr -d ' ')
assert_eq "backup created for existing settings.json" "1" "$bak_count"

summary
