#!/usr/bin/env bash
# Integration tests for network-requiring install scripts:
#   install_caveman.sh, install_claude_code.sh, install_code_review_graph.sh,
#   install_context_mode.sh, install_rtk.sh
#
# Only tests skip and dry-run paths — actual installs require network + external tools.
# Network installs are gated by NETWORK_INTEGRATION_TEST=1
set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "${TESTS_DIR}/.." && pwd)"
source "${TESTS_DIR}/lib/helpers.sh"

setup_tmp

fake_home() { echo "${TMPDIR_TEST}/home_$$_${RANDOM}"; }

# Inject a fake stub binary into a temp bin dir, print the bin dir path
make_fake_cmd() {
    local name="$1"
    local out_dir="${2:-${TMPDIR_TEST}/fakebin_$$_${RANDOM}}"
    mkdir -p "$out_dir"
    printf '#!/bin/sh\necho "fake %s"\nexit 0\n' "$name" > "${out_dir}/${name}"
    chmod +x "${out_dir}/${name}"
    printf '%s' "$out_dir"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# install_claude_code.sh
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SCRIPT_CLAUDE_CODE="${REPO_ROOT}/scripts/install_claude_code.sh"

suite "install_claude_code — --skip"

h=$(fake_home); mkdir -p "$h"
HOME="$h" BOOTSTRAP_SKIP="claude-code" BOOTSTRAP_YES=1 \
  BOOTSTRAP_LOG_DIR="${h}/logs" BOOTSTRAP_DRY_RUN=0 BOOTSTRAP_FORCE=0 \
  bash "$SCRIPT_CLAUDE_CODE" >/dev/null 2>&1
assert_contains "skip: SKIPPED recorded" "SKIPPED" "$(cat "${h}/logs/results.tsv")"

suite "install_claude_code — dry-run"

h=$(fake_home); mkdir -p "$h"
# --force bypasses "already installed" check so dry-run path is reached even when claude is present
out="$(HOME="$h" BOOTSTRAP_SKIP="" BOOTSTRAP_YES=1 \
  BOOTSTRAP_LOG_DIR="${h}/logs" BOOTSTRAP_DRY_RUN=1 BOOTSTRAP_FORCE=1 \
  bash "$SCRIPT_CLAUDE_CODE" 2>&1)"
assert_contains "dry-run: prints Would" "Would" "$out"
assert_contains "dry-run: mentions curl install" "install.sh" "$out"

suite "install_claude_code — already installed skips"

fake_bin="$(make_fake_cmd claude)"
h=$(fake_home); mkdir -p "$h"
PATH="${fake_bin}:${PATH}" HOME="$h" BOOTSTRAP_SKIP="" BOOTSTRAP_YES=1 \
  BOOTSTRAP_LOG_DIR="${h}/logs" BOOTSTRAP_DRY_RUN=0 BOOTSTRAP_FORCE=0 \
  bash "$SCRIPT_CLAUDE_CODE" >/dev/null 2>&1
assert_contains "already-installed: SKIPPED" "SKIPPED" "$(cat "${h}/logs/results.tsv")"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# install_rtk.sh
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SCRIPT_RTK="${REPO_ROOT}/scripts/install_rtk.sh"

suite "install_rtk — --skip"

h=$(fake_home); mkdir -p "$h"
HOME="$h" BOOTSTRAP_SKIP="rtk" BOOTSTRAP_YES=1 \
  BOOTSTRAP_LOG_DIR="${h}/logs" BOOTSTRAP_DRY_RUN=0 BOOTSTRAP_FORCE=0 \
  bash "$SCRIPT_RTK" >/dev/null 2>&1
assert_contains "skip: SKIPPED recorded" "SKIPPED" "$(cat "${h}/logs/results.tsv")"

suite "install_rtk — dry-run"

h=$(fake_home); mkdir -p "$h"
# --force bypasses "already installed" check; dry-run then prints Would
out="$(HOME="$h" BOOTSTRAP_SKIP="" BOOTSTRAP_YES=1 \
  BOOTSTRAP_LOG_DIR="${h}/logs" BOOTSTRAP_DRY_RUN=1 BOOTSTRAP_FORCE=1 \
  bash "$SCRIPT_RTK" 2>&1)"
assert_contains "dry-run: prints Would" "Would" "$out"

suite "install_rtk — already installed with correct binary skips"

fake_bin="${TMPDIR_TEST}/fakebin_rtk_$$"; mkdir -p "$fake_bin"
# Fake rtk that responds to 'rtk gain'
cat > "${fake_bin}/rtk" <<'EOF'
#!/bin/sh
if [ "$1" = "gain" ]; then exit 0; fi
if [ "$1" = "--version" ]; then echo "rtk 1.0.0"; exit 0; fi
exit 0
EOF
chmod +x "${fake_bin}/rtk"

h=$(fake_home); mkdir -p "$h"
PATH="${fake_bin}:${PATH}" HOME="$h" BOOTSTRAP_SKIP="" BOOTSTRAP_YES=1 \
  BOOTSTRAP_LOG_DIR="${h}/logs" BOOTSTRAP_DRY_RUN=0 BOOTSTRAP_FORCE=0 \
  bash "$SCRIPT_RTK" >/dev/null 2>&1
assert_contains "already-installed: SKIPPED" "SKIPPED" "$(cat "${h}/logs/results.tsv")"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# install_code_review_graph.sh
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SCRIPT_CRG="${REPO_ROOT}/scripts/install_code_review_graph.sh"

suite "install_code_review_graph — --skip"

h=$(fake_home); mkdir -p "$h"
HOME="$h" BOOTSTRAP_SKIP="code-review-graph" BOOTSTRAP_YES=1 \
  BOOTSTRAP_LOG_DIR="${h}/logs" BOOTSTRAP_DRY_RUN=0 BOOTSTRAP_FORCE=0 \
  bash "$SCRIPT_CRG" >/dev/null 2>&1
assert_contains "skip: SKIPPED recorded" "SKIPPED" "$(cat "${h}/logs/results.tsv")"

suite "install_code_review_graph — dry-run (uv present)"

# Only run dry-run if uv is available (script requires uv before dry-run path)
if command -v uv >/dev/null 2>&1; then
    h=$(fake_home); mkdir -p "$h"
    # --force bypasses "already installed" check; dry-run then prints Would
    out="$(HOME="$h" BOOTSTRAP_SKIP="" BOOTSTRAP_YES=1 \
      BOOTSTRAP_LOG_DIR="${h}/logs" BOOTSTRAP_DRY_RUN=1 BOOTSTRAP_FORCE=1 \
      bash "$SCRIPT_CRG" 2>&1)"
    assert_contains "dry-run: prints Would" "Would" "$out"
    assert_contains "dry-run: mentions uv tool install" "uv tool install" "$out"
else
    skip "uv not found — skipping code-review-graph dry-run test"
fi

suite "install_code_review_graph — already installed skips"

fake_bin="$(make_fake_cmd code-review-graph)"
h=$(fake_home); mkdir -p "$h"
PATH="${fake_bin}:${PATH}" HOME="$h" BOOTSTRAP_SKIP="" BOOTSTRAP_YES=1 \
  BOOTSTRAP_LOG_DIR="${h}/logs" BOOTSTRAP_DRY_RUN=0 BOOTSTRAP_FORCE=0 \
  bash "$SCRIPT_CRG" >/dev/null 2>&1
assert_contains "already-installed: SKIPPED" "SKIPPED" "$(cat "${h}/logs/results.tsv")"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# install_context_mode.sh
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SCRIPT_CTX="${REPO_ROOT}/scripts/install_context_mode.sh"

suite "install_context_mode — --skip"

h=$(fake_home); mkdir -p "$h"
HOME="$h" BOOTSTRAP_SKIP="context-mode" BOOTSTRAP_YES=1 \
  BOOTSTRAP_LOG_DIR="${h}/logs" BOOTSTRAP_DRY_RUN=0 BOOTSTRAP_FORCE=0 \
  bash "$SCRIPT_CTX" >/dev/null 2>&1
assert_contains "skip: SKIPPED recorded" "SKIPPED" "$(cat "${h}/logs/results.tsv")"

suite "install_context_mode — already installed (plugin dir) skips"

h=$(fake_home); mkdir -p "${h}/.claude/plugins/context-mode"
HOME="$h" BOOTSTRAP_SKIP="" BOOTSTRAP_YES=1 \
  BOOTSTRAP_LOG_DIR="${h}/logs" BOOTSTRAP_DRY_RUN=0 BOOTSTRAP_FORCE=0 \
  bash "$SCRIPT_CTX" >/dev/null 2>&1
assert_contains "already-installed: SKIPPED" "SKIPPED" "$(cat "${h}/logs/results.tsv")"

suite "install_context_mode — dry-run (fake claude)"

fake_bin="${TMPDIR_TEST}/fakebin_ctx_$$"; mkdir -p "$fake_bin"
cat > "${fake_bin}/claude" <<'EOF'
#!/bin/sh
if [ "$1" = "plugin" ] && [ "$2" = "--help" ]; then exit 0; fi
exit 0
EOF
chmod +x "${fake_bin}/claude"

h=$(fake_home); mkdir -p "$h"
out="$(PATH="${fake_bin}:${PATH}" HOME="$h" BOOTSTRAP_SKIP="" BOOTSTRAP_YES=1 \
  BOOTSTRAP_LOG_DIR="${h}/logs" BOOTSTRAP_DRY_RUN=1 BOOTSTRAP_FORCE=0 \
  bash "$SCRIPT_CTX" 2>&1)"
assert_contains "dry-run: prints Would" "Would" "$out"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# install_caveman.sh
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SCRIPT_CAV="${REPO_ROOT}/scripts/install_caveman.sh"

suite "install_caveman — --skip"

h=$(fake_home); mkdir -p "$h"
HOME="$h" BOOTSTRAP_SKIP="caveman" BOOTSTRAP_YES=1 \
  BOOTSTRAP_LOG_DIR="${h}/logs" BOOTSTRAP_DRY_RUN=0 BOOTSTRAP_FORCE=0 \
  bash "$SCRIPT_CAV" >/dev/null 2>&1
assert_contains "skip: SKIPPED recorded" "SKIPPED" "$(cat "${h}/logs/results.tsv")"

suite "install_caveman — already installed (plugin dir) skips"

h=$(fake_home); mkdir -p "${h}/.claude/plugins/caveman"
HOME="$h" BOOTSTRAP_SKIP="" BOOTSTRAP_YES=1 \
  BOOTSTRAP_LOG_DIR="${h}/logs" BOOTSTRAP_DRY_RUN=0 BOOTSTRAP_FORCE=0 \
  bash "$SCRIPT_CAV" >/dev/null 2>&1
assert_contains "already-installed: SKIPPED" "SKIPPED" "$(cat "${h}/logs/results.tsv")"

suite "install_caveman — already installed (settings.json) skips"

h=$(fake_home); mkdir -p "${h}/.claude"
echo '{"hooks":{"caveman":"enabled"}}' > "${h}/.claude/settings.json"
HOME="$h" BOOTSTRAP_SKIP="" BOOTSTRAP_YES=1 \
  BOOTSTRAP_LOG_DIR="${h}/logs" BOOTSTRAP_DRY_RUN=0 BOOTSTRAP_FORCE=0 \
  bash "$SCRIPT_CAV" >/dev/null 2>&1
assert_contains "already-installed via settings: SKIPPED" "SKIPPED" "$(cat "${h}/logs/results.tsv")"

suite "install_caveman — dry-run (fake claude)"

fake_bin="${TMPDIR_TEST}/fakebin_cav_$$"; mkdir -p "$fake_bin"
printf '#!/bin/sh\nexit 0\n' > "${fake_bin}/claude"
chmod +x "${fake_bin}/claude"

h=$(fake_home); mkdir -p "$h"
out="$(PATH="${fake_bin}:${PATH}" HOME="$h" BOOTSTRAP_SKIP="" BOOTSTRAP_YES=1 \
  BOOTSTRAP_LOG_DIR="${h}/logs" BOOTSTRAP_DRY_RUN=1 BOOTSTRAP_FORCE=0 \
  bash "$SCRIPT_CAV" 2>&1)"
assert_contains "dry-run: prints Would or claude" "caveman" "$out"

summary
