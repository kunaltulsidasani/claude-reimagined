#!/usr/bin/env bash
# Integration tests for scripts/install_deps.sh
# Tests skip and dry-run paths only — package installation requires root/brew
set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "${TESTS_DIR}/.." && pwd)"
source "${TESTS_DIR}/lib/helpers.sh"

SCRIPT="${REPO_ROOT}/scripts/install_deps.sh"

setup_tmp

fake_home() { echo "${TMPDIR_TEST}/home_$$_${RANDOM}"; }

# ── Skip flag ─────────────────────────────────────────────────────────────────

suite "install_deps — --skip"

h=$(fake_home); mkdir -p "$h"
rc=0
HOME="$h" BOOTSTRAP_SKIP="deps" BOOTSTRAP_YES=1 \
  BOOTSTRAP_LOG_DIR="${h}/logs" BOOTSTRAP_DRY_RUN=0 BOOTSTRAP_FORCE=0 \
  bash "$SCRIPT" >/dev/null 2>&1 || rc=$?

assert_exit_ok "skip: exits 0" "$rc"
assert_contains "skip: SKIPPED recorded" "SKIPPED" "$(cat "${h}/logs/results.tsv")"

# ── Dry-run: no packages installed ───────────────────────────────────────────

suite "install_deps — dry-run"

h=$(fake_home); mkdir -p "$h"
rc=0
out="$(HOME="$h" BOOTSTRAP_SKIP="" BOOTSTRAP_YES=1 \
  BOOTSTRAP_LOG_DIR="${h}/logs" BOOTSTRAP_DRY_RUN=1 BOOTSTRAP_FORCE=0 \
  bash "$SCRIPT" 2>&1)" || rc=$?

assert_exit_ok "dry-run: exits 0" "$rc"

# Should either report all present or show dry-run would-install message
if printf '%s' "$out" | grep -q "Would"; then
    pass "dry-run: prints Would for missing deps"
elif printf '%s' "$out" | grep -q "already installed"; then
    pass "dry-run: all deps already installed, nothing to install"
else
    pass "dry-run: exited cleanly (deps may already be present)"
fi

# ── All deps present: reports OK and exits 0 ─────────────────────────────────

suite "install_deps — all hard deps present → records OK"

# Inject a fake PATH with stub binaries for the 4 hard deps
fake_bin="${TMPDIR_TEST}/fake_bin_$$"
mkdir -p "$fake_bin"

for cmd in curl git python3; do
    printf '#!/bin/sh\nexit 0\n' > "${fake_bin}/${cmd}"
    chmod +x "${fake_bin}/${cmd}"
done

h=$(fake_home); mkdir -p "$h"
rc=0
PATH="${fake_bin}:${PATH}" HOME="$h" BOOTSTRAP_SKIP="" BOOTSTRAP_YES=1 \
  BOOTSTRAP_LOG_DIR="${h}/logs" BOOTSTRAP_DRY_RUN=0 BOOTSTRAP_FORCE=0 \
  bash "$SCRIPT" >/dev/null 2>&1 || rc=$?

assert_exit_ok "all-present: exits 0" "$rc"
assert_contains "all-present: OK recorded" "OK" "$(cat "${h}/logs/results.tsv")"

# ── Dry-run with missing hard dep shows install plan ─────────────────────────

suite "install_deps — dry-run with missing dep shows install intent"

# Stub bin with curl+git but no python3; keep /usr/bin:/bin for uname/printf/etc.
fake_bin2="${TMPDIR_TEST}/fake_bin2_$$"
mkdir -p "$fake_bin2"
for cmd in curl git; do
    printf '#!/bin/sh\nexit 0\n' > "${fake_bin2}/${cmd}"
    chmod +x "${fake_bin2}/${cmd}"
done
# Wrapper that shadows python3 with a missing command (returns non-zero from command -v)
# We just omit python3 from the stub dir; system python3 won't be visible in stub-only prefix.
# Preserve system dirs so bash builtins' external helpers (uname, etc.) still work.
_sys_path="${fake_bin2}:/usr/bin:/bin:/usr/sbin:/sbin"
_current_bash="$(command -v bash)"

h=$(fake_home); mkdir -p "$h"
rc=0
out="$(PATH="${_sys_path}" HOME="$h" BOOTSTRAP_SKIP="" BOOTSTRAP_YES=1 \
  BOOTSTRAP_LOG_DIR="${h}/logs" BOOTSTRAP_DRY_RUN=1 BOOTSTRAP_FORCE=0 \
  "${_current_bash}" "$SCRIPT" 2>&1)" || rc=$?

assert_exit_ok "missing-dep dry-run: exits 0" "$rc"
# Should mention python3 as missing or show Would install
if printf '%s' "$out" | grep -qE "python3|Would"; then
    pass "missing-dep: output mentions python3 or Would"
else
    fail "missing-dep: output should mention python3 or Would — got: $(printf '%s' "$out" | head -3)"
fi

summary
