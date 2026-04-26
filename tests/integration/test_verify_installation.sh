#!/usr/bin/env bash
# Integration tests for scripts/verify_installation.sh
# Sets up fake ~/.claude state and runs the verifier — never touches real ~/.claude
set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "${TESTS_DIR}/.." && pwd)"
source "${TESTS_DIR}/lib/helpers.sh"

SCRIPT="${REPO_ROOT}/scripts/verify_installation.sh"

setup_tmp

fake_home() { echo "${TMPDIR_TEST}/home_$$_${RANDOM}"; }

# Helper: write results.tsv entries to mark components as SKIPPED
# Usage: write_skipped <log_dir> <component_id> [<component_id> ...]
write_skipped() {
    local log_dir="$1"; shift
    mkdir -p "$log_dir"
    for cid in "$@"; do
        printf '%s\t%-25s\tSKIPPED\tskipped in test\n' \
          "$(date '+%Y-%m-%d %H:%M:%S')" "$cid" >> "${log_dir}/results.tsv"
    done
}

# Helper: create minimal settings.json containing given strings
write_settings() {
    local path="$1"; shift
    local content='{'
    local first=1
    for kv in "$@"; do
        local key="${kv%%:*}"
        local val="${kv#*:}"
        [[ "$first" == "1" ]] || content+=','
        content+='"'"$key"'":"'"$val"'"'
        first=0
    done
    content+='}'
    mkdir -p "$(dirname "$path")"
    printf '%s\n' "$content" > "$path"
}

# ── All skippable components skipped, local checks pass → exit 0 ──────────────

suite "verify_installation — all passing (skipped where needed)"

h=$(fake_home); mkdir -p "${h}/.claude/hooks" "${h}/.claude/plugins"

# Mark network-install components SKIPPED in results.tsv
log_dir="${h}/logs"
write_skipped "$log_dir" "claude-code" "rtk" "code-review-graph"

# context-mode: fake plugin dir entry
mkdir -p "${h}/.claude/plugins/context-mode-plugin"

# caveman: presence in settings.json
settings="${h}/.claude/settings.json"
printf '{"caveman":"enabled","context-mode":"enabled","subagent-model-router":"enabled"}\n' > "$settings"

# statusline: executable file
printf '#!/bin/sh\necho ok\n' > "${h}/.claude/statusline.sh"
chmod +x "${h}/.claude/statusline.sh"

# subagent-router: hook file + settings.json reference (already in settings above)
cp "${REPO_ROOT}/hooks/subagent-model-router.sh" "${h}/.claude/hooks/subagent-model-router.sh"
chmod +x "${h}/.claude/hooks/subagent-model-router.sh"

# claude-md, settings
printf '# Claude MD\n' > "${h}/.claude/CLAUDE.md"
# settings.json already created above

rc=0
HOME="$h" BOOTSTRAP_LOG_DIR="${log_dir}" \
  bash "$SCRIPT" >/dev/null 2>&1 || rc=$?

assert_exit_ok "all-pass: verify exits 0" "$rc"

# ── Nothing installed → exit 1 ────────────────────────────────────────────────

suite "verify_installation — nothing installed → exits 1"

h=$(fake_home); mkdir -p "$h"
log_dir="${h}/logs"; mkdir -p "$log_dir"

rc=0
HOME="$h" BOOTSTRAP_LOG_DIR="${log_dir}" \
  bash "$SCRIPT" >/dev/null 2>&1 || rc=$?

assert_exit_fail "nothing-installed: verify exits non-zero" "$rc"

# ── Output contains component names ───────────────────────────────────────────

suite "verify_installation — output lists expected component checks"

h=$(fake_home); mkdir -p "${h}/.claude/hooks" "${h}/.claude/plugins"
log_dir="${h}/logs"
write_skipped "$log_dir" "claude-code" "rtk" "code-review-graph"

mkdir -p "${h}/.claude/plugins/context-mode-plugin"
printf '{"caveman":"enabled","context-mode":"enabled","subagent-model-router":"enabled"}\n' \
  > "${h}/.claude/settings.json"
printf '#!/bin/sh\necho ok\n' > "${h}/.claude/statusline.sh"; chmod +x "${h}/.claude/statusline.sh"
cp "${REPO_ROOT}/hooks/subagent-model-router.sh" "${h}/.claude/hooks/subagent-model-router.sh"
chmod +x "${h}/.claude/hooks/subagent-model-router.sh"
printf '# Claude MD\n' > "${h}/.claude/CLAUDE.md"

out="$(HOME="$h" BOOTSTRAP_LOG_DIR="${log_dir}" bash "$SCRIPT" 2>&1)"

assert_contains "output: claude-code entry"     "claude-code"     "$out"
assert_contains "output: statusline entry"      "statusline"      "$out"
assert_contains "output: subagent entry"        "subagent"        "$out"
assert_contains "output: CLAUDE.md entry"       "CLAUDE"          "$out"
assert_contains "output: summary line"          "components OK"   "$out"

# ── Statusline not executable → FAIL ─────────────────────────────────────────

suite "verify_installation — non-executable statusline.sh → reports failure"

h=$(fake_home); mkdir -p "${h}/.claude/hooks" "${h}/.claude/plugins"
log_dir="${h}/logs"
write_skipped "$log_dir" "claude-code" "rtk" "code-review-graph"

mkdir -p "${h}/.claude/plugins/context-mode-plugin"
printf '{"caveman":"enabled","context-mode":"enabled","subagent-model-router":"enabled"}\n' \
  > "${h}/.claude/settings.json"

# statusline exists but NOT executable
printf '#!/bin/sh\necho ok\n' > "${h}/.claude/statusline.sh"
# do NOT chmod +x

cp "${REPO_ROOT}/hooks/subagent-model-router.sh" "${h}/.claude/hooks/subagent-model-router.sh"
chmod +x "${h}/.claude/hooks/subagent-model-router.sh"
printf '# Claude MD\n' > "${h}/.claude/CLAUDE.md"

rc=0
out="$(HOME="$h" BOOTSTRAP_LOG_DIR="${log_dir}" bash "$SCRIPT" 2>&1)" || rc=$?

assert_exit_fail "non-exec statusline: verify exits non-zero" "$rc"
assert_contains  "non-exec statusline: FAIL in output" "FAIL" "$out"

# ── Missing CLAUDE.md → FAIL ──────────────────────────────────────────────────

suite "verify_installation — missing CLAUDE.md → reports failure"

h=$(fake_home); mkdir -p "${h}/.claude/hooks" "${h}/.claude/plugins"
log_dir="${h}/logs"
write_skipped "$log_dir" "claude-code" "rtk" "code-review-graph"

mkdir -p "${h}/.claude/plugins/context-mode-plugin"
printf '{"caveman":"enabled","context-mode":"enabled","subagent-model-router":"enabled"}\n' \
  > "${h}/.claude/settings.json"
printf '#!/bin/sh\necho ok\n' > "${h}/.claude/statusline.sh"; chmod +x "${h}/.claude/statusline.sh"
cp "${REPO_ROOT}/hooks/subagent-model-router.sh" "${h}/.claude/hooks/subagent-model-router.sh"
chmod +x "${h}/.claude/hooks/subagent-model-router.sh"
# CLAUDE.md intentionally NOT created

rc=0
out="$(HOME="$h" BOOTSTRAP_LOG_DIR="${log_dir}" bash "$SCRIPT" 2>&1)" || rc=$?

assert_exit_fail "missing CLAUDE.md: verify exits non-zero" "$rc"
assert_contains  "missing CLAUDE.md: FAIL in output" "FAIL" "$out"

# ── Skipped-in-results.tsv components counted as SKIP, not FAIL ───────────────

suite "verify_installation — SKIPPED components not counted as failures"

h=$(fake_home); mkdir -p "${h}/.claude/hooks" "${h}/.claude/plugins"
log_dir="${h}/logs"
# Mark ALL non-local components as SKIPPED (caveman, rtk, code-review-graph, context-mode, claude-code)
write_skipped "$log_dir" "claude-code" "rtk" "code-review-graph" "caveman" "context-mode"

# Only local filesystem components present
printf '{"subagent-model-router":"enabled"}\n' > "${h}/.claude/settings.json"
printf '#!/bin/sh\necho ok\n' > "${h}/.claude/statusline.sh"; chmod +x "${h}/.claude/statusline.sh"
cp "${REPO_ROOT}/hooks/subagent-model-router.sh" "${h}/.claude/hooks/subagent-model-router.sh"
chmod +x "${h}/.claude/hooks/subagent-model-router.sh"
printf '# Claude MD\n' > "${h}/.claude/CLAUDE.md"

rc=0
HOME="$h" BOOTSTRAP_LOG_DIR="${log_dir}" bash "$SCRIPT" >/dev/null 2>&1 || rc=$?

assert_exit_ok "all-skipped-ok: verify exits 0 when failures are skipped" "$rc"

summary
