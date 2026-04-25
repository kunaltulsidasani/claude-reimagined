#!/usr/bin/env bash
# Integration tests for scripts/install_subagent_router.sh
# Overrides HOME to tmp — never touches real ~/.claude
set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "${TESTS_DIR}/.." && pwd)"
source "${TESTS_DIR}/lib/helpers.sh"

SCRIPT="${REPO_ROOT}/scripts/install_subagent_router.sh"

setup_tmp

fake_home() { echo "${TMPDIR_TEST}/home_$$_${RANDOM}"; }

# ── Skip flag ─────────────────────────────────────────────────────────────────

suite "install_subagent_router — --skip"

h=$(fake_home); mkdir -p "$h"
HOME="$h" BOOTSTRAP_SKIP="subagent-router" BOOTSTRAP_YES=1 \
  BOOTSTRAP_LOG_DIR="${h}/logs" BOOTSTRAP_DRY_RUN=0 BOOTSTRAP_FORCE=0 \
  bash "$SCRIPT" >/dev/null 2>&1

assert_file_not_exists "skip: hook not copied" "${h}/.claude/hooks/subagent-model-router.sh"
assert_contains "skip: SKIPPED" "SKIPPED" "$(cat "${h}/logs/results.tsv")"

# ── Dry-run ───────────────────────────────────────────────────────────────────

suite "install_subagent_router — dry-run"

h=$(fake_home); mkdir -p "$h"
HOME="$h" BOOTSTRAP_SKIP="" BOOTSTRAP_YES=1 \
  BOOTSTRAP_LOG_DIR="${h}/logs" BOOTSTRAP_DRY_RUN=1 BOOTSTRAP_FORCE=0 \
  bash "$SCRIPT" >/dev/null 2>&1

assert_file_not_exists "dry-run: hook not copied" "${h}/.claude/hooks/subagent-model-router.sh"

# ── Normal install ────────────────────────────────────────────────────────────

suite "install_subagent_router — normal install"

h=$(fake_home); mkdir -p "$h"
HOME="$h" BOOTSTRAP_SKIP="" BOOTSTRAP_YES=1 \
  BOOTSTRAP_LOG_DIR="${h}/logs" BOOTSTRAP_DRY_RUN=0 BOOTSTRAP_FORCE=0 \
  bash "$SCRIPT" >/dev/null 2>&1

dest="${h}/.claude/hooks/subagent-model-router.sh"
assert_file_exists "hook file copied"     "$dest"
assert_executable  "hook file executable" "$dest"

settings="${h}/.claude/settings.json"
assert_file_exists "settings.json created" "$settings"

content=$(cat "$settings")
assert_contains "PreToolUse registered"    "PreToolUse"             "$content"
assert_contains "Agent matcher present"    "Agent"                  "$content"
assert_contains "hook path in command"     "subagent-model-router"  "$content"

python3 -c "import json; json.load(open('${settings}'))" 2>/dev/null \
  && pass "settings.json is valid JSON" \
  || fail "settings.json is valid JSON"

assert_contains "OK recorded" "OK" "$(cat "${h}/logs/results.tsv")"

# ── Already installed — no --force ────────────────────────────────────────────

suite "install_subagent_router — already installed, no --force"

h=$(fake_home); mkdir -p "${h}/.claude/hooks"
cp "${REPO_ROOT}/hooks/subagent-model-router.sh" "${h}/.claude/hooks/subagent-model-router.sh"
echo '{"hooks":{"PreToolUse":[{"matcher":"Agent","hooks":[{"type":"command","command":"bash \"'"${h}"'/.claude/hooks/subagent-model-router.sh\""}]}]}}' \
  > "${h}/.claude/settings.json"

HOME="$h" BOOTSTRAP_SKIP="" BOOTSTRAP_YES=1 \
  BOOTSTRAP_LOG_DIR="${h}/logs" BOOTSTRAP_DRY_RUN=0 BOOTSTRAP_FORCE=0 \
  bash "$SCRIPT" >/dev/null 2>&1

assert_contains "already installed: SKIPPED" "SKIPPED" "$(cat "${h}/logs/results.tsv")"

# ── --force reinstalls ────────────────────────────────────────────────────────

suite "install_subagent_router — --force"

h=$(fake_home); mkdir -p "${h}/.claude/hooks"
cp "${REPO_ROOT}/hooks/subagent-model-router.sh" "${h}/.claude/hooks/subagent-model-router.sh"
echo '{"hooks":{"PreToolUse":[{"matcher":"Agent","hooks":[{"type":"command","command":"bash \"'"${h}"'/.claude/hooks/subagent-model-router.sh\""}]}]}}' \
  > "${h}/.claude/settings.json"

HOME="$h" BOOTSTRAP_SKIP="" BOOTSTRAP_YES=1 \
  BOOTSTRAP_LOG_DIR="${h}/logs" BOOTSTRAP_DRY_RUN=0 BOOTSTRAP_FORCE=1 \
  bash "$SCRIPT" >/dev/null 2>&1

assert_contains "force: OK" "OK" "$(cat "${h}/logs/results.tsv")"

summary
