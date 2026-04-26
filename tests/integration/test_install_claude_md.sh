#!/usr/bin/env bash
# Integration tests for scripts/install_claude_md.sh
# Overrides HOME to tmp — never touches real ~/.claude
set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "${TESTS_DIR}/.." && pwd)"
source "${TESTS_DIR}/lib/helpers.sh"

SCRIPT="${REPO_ROOT}/scripts/install_claude_md.sh"
SRC_CLAUDE_MD="${REPO_ROOT}/configs/CLAUDE.md"
SRC_RTK_MD="${REPO_ROOT}/configs/RTK.md"

if [[ ! -f "${SRC_CLAUDE_MD}" || ! -f "${SRC_RTK_MD}" ]]; then
    skip "configs/CLAUDE.md or configs/RTK.md not found — skipping (create them first)"
    summary; exit 0
fi

if ! command -v python3 >/dev/null 2>&1; then
    skip "python3 not found — skipping install_claude_md tests"
    summary; exit 0
fi

setup_tmp

fake_home() { echo "${TMPDIR_TEST}/home_$$_${RANDOM}"; }

# ── Skip flag ─────────────────────────────────────────────────────────────────

suite "install_claude_md — --skip"

h=$(fake_home); mkdir -p "$h"
HOME="$h" BOOTSTRAP_SKIP="claude-md" BOOTSTRAP_YES=1 \
  BOOTSTRAP_LOG_DIR="${h}/logs" BOOTSTRAP_DRY_RUN=0 BOOTSTRAP_FORCE=0 \
  bash "$SCRIPT" >/dev/null 2>&1

assert_file_not_exists "skip: CLAUDE.md not created" "${h}/.claude/CLAUDE.md"
assert_file_not_exists "skip: RTK.md not created"    "${h}/.claude/RTK.md"
assert_contains "skip: SKIPPED recorded" "SKIPPED" "$(cat "${h}/logs/results.tsv")"

# ── Dry-run ───────────────────────────────────────────────────────────────────

suite "install_claude_md — dry-run"

h=$(fake_home); mkdir -p "$h"
out="$(HOME="$h" BOOTSTRAP_SKIP="" BOOTSTRAP_YES=1 \
  BOOTSTRAP_LOG_DIR="${h}/logs" BOOTSTRAP_DRY_RUN=1 BOOTSTRAP_FORCE=0 \
  bash "$SCRIPT" 2>&1)"

assert_file_not_exists "dry-run: CLAUDE.md not written" "${h}/.claude/CLAUDE.md"
assert_file_not_exists "dry-run: RTK.md not written"    "${h}/.claude/RTK.md"
assert_contains "dry-run: prints Would" "Would" "$out"

# ── Fresh install ─────────────────────────────────────────────────────────────

suite "install_claude_md — fresh install"

h=$(fake_home); mkdir -p "$h"
HOME="$h" BOOTSTRAP_SKIP="" BOOTSTRAP_YES=1 \
  BOOTSTRAP_LOG_DIR="${h}/logs" BOOTSTRAP_DRY_RUN=0 BOOTSTRAP_FORCE=0 \
  bash "$SCRIPT" >/dev/null 2>&1

assert_file_exists "CLAUDE.md created" "${h}/.claude/CLAUDE.md"
assert_file_exists "RTK.md created"    "${h}/.claude/RTK.md"
assert_contains "OK recorded" "OK" "$(cat "${h}/logs/results.tsv")"

src_first_line="$(head -1 "${SRC_CLAUDE_MD}")"
assert_contains "CLAUDE.md has src content" "$src_first_line" "$(cat "${h}/.claude/CLAUDE.md")"

src_rtk_line="$(head -1 "${SRC_RTK_MD}")"
assert_contains "RTK.md has src content" "$src_rtk_line" "$(cat "${h}/.claude/RTK.md")"

# ── Already installed: no --force, skips ─────────────────────────────────────

suite "install_claude_md — already installed, no --force"

h=$(fake_home); mkdir -p "${h}/.claude"
echo "my existing claude.md content" > "${h}/.claude/CLAUDE.md"
echo "my existing rtk.md content"    > "${h}/.claude/RTK.md"

HOME="$h" BOOTSTRAP_SKIP="" BOOTSTRAP_YES=1 \
  BOOTSTRAP_LOG_DIR="${h}/logs" BOOTSTRAP_DRY_RUN=0 BOOTSTRAP_FORCE=0 \
  bash "$SCRIPT" >/dev/null 2>&1

assert_contains "no-force: SKIPPED recorded" "SKIPPED" "$(cat "${h}/logs/results.tsv")"
assert_contains "no-force: CLAUDE.md unchanged" "my existing claude.md content" \
  "$(cat "${h}/.claude/CLAUDE.md")"

# ── --force: overwrites RTK.md, merges CLAUDE.md, creates backup ──────────────

suite "install_claude_md — --force reinstall"

h=$(fake_home); mkdir -p "${h}/.claude"
echo "user's existing line" > "${h}/.claude/CLAUDE.md"
echo "old rtk content"      > "${h}/.claude/RTK.md"

HOME="$h" BOOTSTRAP_SKIP="" BOOTSTRAP_YES=1 \
  BOOTSTRAP_LOG_DIR="${h}/logs" BOOTSTRAP_DRY_RUN=0 BOOTSTRAP_FORCE=1 \
  bash "$SCRIPT" >/dev/null 2>&1

assert_contains "force: OK recorded" "OK" "$(cat "${h}/logs/results.tsv")"

rtk_src_line="$(head -1 "${SRC_RTK_MD}")"
assert_contains "force: RTK.md overwritten with src" "$rtk_src_line" "$(cat "${h}/.claude/RTK.md")"

bak_count=$(find "${h}/.claude" -name "CLAUDE.md.bak.*" 2>/dev/null | wc -l | tr -d ' ')
assert_eq "force: CLAUDE.md backup created" "1" "$bak_count"

# ── Merge: existing CLAUDE.md gets missing lines appended ────────────────────

suite "install_claude_md — merge appends missing src lines"

h=$(fake_home); mkdir -p "${h}/.claude"
# Seed dest with only the first line from source — rest should be merged in
first_src_line="$(head -1 "${SRC_CLAUDE_MD}")"
echo "$first_src_line" > "${h}/.claude/CLAUDE.md"
echo "placeholder"     > "${h}/.claude/RTK.md"

HOME="$h" BOOTSTRAP_SKIP="" BOOTSTRAP_YES=1 \
  BOOTSTRAP_LOG_DIR="${h}/logs" BOOTSTRAP_DRY_RUN=0 BOOTSTRAP_FORCE=1 \
  bash "$SCRIPT" >/dev/null 2>&1

src_line_count="$(wc -l < "${SRC_CLAUDE_MD}")"
dest_line_count="$(wc -l < "${h}/.claude/CLAUDE.md")"
[[ "$dest_line_count" -ge "$src_line_count" ]] \
  && pass "merge: dest lines (${dest_line_count}) >= src lines (${src_line_count})" \
  || fail "merge: dest lines (${dest_line_count}) < src lines (${src_line_count})"

summary
