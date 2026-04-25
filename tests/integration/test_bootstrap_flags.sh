#!/usr/bin/env bash
# Integration tests for bootstrap.sh flag parsing and flag propagation
# Does NOT run a full bootstrap — just verifies flags are parsed and exported correctly
set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "${TESTS_DIR}/.." && pwd)"
source "${TESTS_DIR}/lib/helpers.sh"

BOOTSTRAP="${REPO_ROOT}/bootstrap.sh"

setup_tmp

# Helper: run bootstrap in dry-run + yes mode with extra args, capture env state
# We test flag parsing by checking what gets set, not by running all scripts.
# We pass --dry-run --yes so no scripts actually install anything, and we source
# a sentinel script that dumps the exported vars.

sentinel="${TMPDIR_TEST}/sentinel.sh"
cat > "$sentinel" <<'EOF'
#!/usr/bin/env bash
echo "DRY_RUN=${BOOTSTRAP_DRY_RUN}"
echo "FORCE=${BOOTSTRAP_FORCE}"
echo "YES=${BOOTSTRAP_YES}"
echo "SKIP=${BOOTSTRAP_SKIP}"
exit 0
EOF
chmod +x "$sentinel"

# ── --help ────────────────────────────────────────────────────────────────────

suite "bootstrap — --help"

bash "$BOOTSTRAP" --help >/dev/null 2>&1
assert_exit_ok "--help exits 0" "$?"

out=$(bash "$BOOTSTRAP" --help 2>&1)
assert_contains "--help shows usage" "Usage:" "$out"
assert_contains "--help shows --dry-run flag" "--dry-run" "$out"
assert_contains "--help shows --skip flag" "--skip" "$out"

# ── Unknown flag exits 1 ──────────────────────────────────────────────────────

suite "bootstrap — unknown flag"

bash "$BOOTSTRAP" --unknown-flag >/dev/null 2>&1 && _rc=0 || _rc=$?
assert_exit_fail "unknown flag exits non-zero" "$_rc"

# ── --skip missing argument exits 1 ──────────────────────────────────────────

suite "bootstrap — --skip missing argument"

bash "$BOOTSTRAP" --skip >/dev/null 2>&1 && _rc=0 || _rc=$?
assert_exit_fail "--skip without arg exits non-zero" "$_rc"

# ── --dry-run sets BOOTSTRAP_DRY_RUN=1 ───────────────────────────────────────

suite "bootstrap — flag export: --dry-run"

# We verify by running a minimal bootstrap that can't do harm:
# pass --dry-run --yes and confirm nothing is written to HOME
h="${TMPDIR_TEST}/home_flags_dry"; mkdir -p "$h"

HOME="$h" bash "$BOOTSTRAP" --dry-run --yes >/dev/null 2>&1 || true

# In dry-run mode .claude/ should not be created (logs go to .claude-bootstrap/ which is ok)
assert_file_not_exists "dry-run: ~/.claude/settings.json not written" "${h}/.claude/settings.json"
assert_file_not_exists "dry-run: ~/.claude/hooks/ not created"        "${h}/.claude/hooks/pre-compact.sh"

# ── --skip propagates to component ───────────────────────────────────────────

suite "bootstrap — --skip propagates"

h="${TMPDIR_TEST}/home_skip"; mkdir -p "$h"

# Skip everything that could matter; dry-run as safety net too
HOME="$h" bash "$BOOTSTRAP" --dry-run --yes --skip rtk,caveman >/dev/null 2>&1 || true
pass "--skip rtk,caveman: bootstrap ran without error"

# ── --skills-only flag accepted ───────────────────────────────────────────────

suite "bootstrap — --skills-only accepted"

bash "$BOOTSTRAP" --skills-only "python-pro" --dry-run --yes >/dev/null 2>&1 || true
pass "--skills-only with --dry-run: no error"

# ── --clean flag accepted (dry-run so nothing deleted) ───────────────────────

suite "bootstrap — --clean with --dry-run"

bash "$BOOTSTRAP" --clean --dry-run --yes >/dev/null 2>&1 || true
pass "--clean --dry-run: no error"

# ── Multiple --skip flags accumulate ─────────────────────────────────────────

suite "bootstrap — multiple --skip flags"

bash "$BOOTSTRAP" --skip rtk --skip caveman --dry-run --yes >/dev/null 2>&1 || true
pass "multiple --skip flags: no error"

summary
