#!/usr/bin/env bash
# Tests for lib/common.sh — flag helpers, is_skipped, detect_os/arch, backup_file, record_result
set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "${TESTS_DIR}/.." && pwd)"
source "${TESTS_DIR}/lib/helpers.sh"

setup_tmp

# ── is_dry_run / is_force / is_yes ───────────────────────────────────────────

suite "is_dry_run"

(
  source "${REPO_ROOT}/lib/common.sh"
  BOOTSTRAP_DRY_RUN=1
  is_dry_run && exit 0 || exit 1
) && pass "returns true when BOOTSTRAP_DRY_RUN=1" || fail "returns true when BOOTSTRAP_DRY_RUN=1"

(
  source "${REPO_ROOT}/lib/common.sh"
  BOOTSTRAP_DRY_RUN=0
  is_dry_run && exit 1 || exit 0
) && pass "returns false when BOOTSTRAP_DRY_RUN=0" || fail "returns false when BOOTSTRAP_DRY_RUN=0"

suite "is_force"

(
  source "${REPO_ROOT}/lib/common.sh"
  BOOTSTRAP_FORCE=1
  is_force && exit 0 || exit 1
) && pass "returns true when BOOTSTRAP_FORCE=1" || fail "returns true when BOOTSTRAP_FORCE=1"

(
  source "${REPO_ROOT}/lib/common.sh"
  BOOTSTRAP_FORCE=0
  is_force && exit 1 || exit 0
) && pass "returns false when BOOTSTRAP_FORCE=0" || fail "returns false when BOOTSTRAP_FORCE=0"

suite "is_yes"

(
  source "${REPO_ROOT}/lib/common.sh"
  BOOTSTRAP_YES=1
  is_yes && exit 0 || exit 1
) && pass "returns true when BOOTSTRAP_YES=1" || fail "returns true when BOOTSTRAP_YES=1"

(
  source "${REPO_ROOT}/lib/common.sh"
  BOOTSTRAP_YES=0
  is_yes && exit 1 || exit 0
) && pass "returns false when BOOTSTRAP_YES=0" || fail "returns false when BOOTSTRAP_YES=0"

# ── is_skipped ────────────────────────────────────────────────────────────────

suite "is_skipped"

(
  source "${REPO_ROOT}/lib/common.sh"
  BOOTSTRAP_SKIP="rtk"
  is_skipped "rtk" && exit 0 || exit 1
) && pass "single component match" || fail "single component match"

(
  source "${REPO_ROOT}/lib/common.sh"
  BOOTSTRAP_SKIP="rtk,caveman"
  is_skipped "caveman" && exit 0 || exit 1
) && pass "second in comma-separated list" || fail "second in comma-separated list"

(
  source "${REPO_ROOT}/lib/common.sh"
  BOOTSTRAP_SKIP="rtk, caveman"
  is_skipped "caveman" && exit 0 || exit 1
) && pass "handles spaces around comma" || fail "handles spaces around comma"

(
  source "${REPO_ROOT}/lib/common.sh"
  BOOTSTRAP_SKIP="rtk"
  is_skipped "caveman" && exit 1 || exit 0
) && pass "returns false for non-skipped component" || fail "returns false for non-skipped component"

(
  source "${REPO_ROOT}/lib/common.sh"
  BOOTSTRAP_SKIP=""
  is_skipped "rtk" && exit 1 || exit 0
) && pass "returns false when skip list is empty" || fail "returns false when skip list is empty"

# ── check_command ─────────────────────────────────────────────────────────────

suite "check_command"

(
  source "${REPO_ROOT}/lib/common.sh"
  check_command "bash" && exit 0 || exit 1
) && pass "finds bash" || fail "finds bash"

(
  source "${REPO_ROOT}/lib/common.sh"
  check_command "__definitely_not_a_real_command__" && exit 1 || exit 0
) && pass "returns false for missing command" || fail "returns false for missing command"

# ── detect_os ─────────────────────────────────────────────────────────────────

suite "detect_os"

os=$(
  source "${REPO_ROOT}/lib/common.sh"
  detect_os
)
case "$(uname -s)" in
  Darwin) assert_eq "detect_os on Darwin → macos" "macos" "$os" ;;
  Linux)  assert_eq "detect_os on Linux → linux"  "linux" "$os" ;;
  *)      skip "detect_os (unknown platform: $(uname -s))" ;;
esac

# ── detect_arch ───────────────────────────────────────────────────────────────

suite "detect_arch"

arch=$(
  source "${REPO_ROOT}/lib/common.sh"
  detect_arch
)
case "$(uname -m)" in
  x86_64|amd64)  assert_eq "detect_arch x86_64" "x86_64" "$arch" ;;
  arm64|aarch64) assert_eq "detect_arch arm64"   "arm64"  "$arch" ;;
  *)             skip "detect_arch (unknown machine: $(uname -m))" ;;
esac

# ── backup_file ───────────────────────────────────────────────────────────────

suite "backup_file"

original="${TMPDIR_TEST}/original.txt"
echo "hello" > "$original"

(
  export BOOTSTRAP_DRY_RUN=0
  export BOOTSTRAP_LOG_DIR="${TMPDIR_TEST}/logs"
  source "${REPO_ROOT}/lib/common.sh"
  backup_file "$original" >/dev/null
)

bak_count=$(find "${TMPDIR_TEST}" -name "original.txt.bak.*" | wc -l | tr -d ' ')
assert_eq "creates .bak. file" "1" "$bak_count"

# dry-run: no backup written
original2="${TMPDIR_TEST}/original2.txt"
echo "hello" > "$original2"

(
  export BOOTSTRAP_DRY_RUN=1
  export BOOTSTRAP_LOG_DIR="${TMPDIR_TEST}/logs"
  source "${REPO_ROOT}/lib/common.sh"
  backup_file "$original2" >/dev/null
)

bak_count2=$(find "${TMPDIR_TEST}" -name "original2.txt.bak.*" | wc -l | tr -d ' ')
assert_eq "dry-run: no .bak. file created" "0" "$bak_count2"

# ── record_result ─────────────────────────────────────────────────────────────

suite "record_result"

log_dir="${TMPDIR_TEST}/logs2"

(
  export BOOTSTRAP_LOG_DIR="$log_dir"
  source "${REPO_ROOT}/lib/common.sh"
  record_result "my-component" "OK" "installed fine"
)

tsv="${log_dir}/results.tsv"
assert_file_exists "creates results.tsv" "$tsv"
assert_contains "contains component name" "my-component" "$(cat "$tsv")"
assert_contains "contains status OK"      "OK"           "$(cat "$tsv")"
assert_contains "contains details"        "installed fine" "$(cat "$tsv")"

summary
