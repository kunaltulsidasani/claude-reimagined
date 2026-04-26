#!/usr/bin/env bash
# Shared helpers for all bootstrap scripts.
# Source this file at the top of each script: source "$(dirname "$0")/../lib/common.sh"
set -euo pipefail

# ── Runtime flags (set by bootstrap.sh or the environment) ──────────────────
BOOTSTRAP_DRY_RUN="${BOOTSTRAP_DRY_RUN:-0}"
BOOTSTRAP_FORCE="${BOOTSTRAP_FORCE:-0}"
BOOTSTRAP_YES="${BOOTSTRAP_YES:-0}"
BOOTSTRAP_SKIP="${BOOTSTRAP_SKIP:-}"
BOOTSTRAP_LOG_DIR="${BOOTSTRAP_LOG_DIR:-${HOME}/.claude-bootstrap/logs}"

# ── Colors ───────────────────────────────────────────────────────────────────
_RED='\033[0;31m'
_GREEN='\033[0;32m'
_YELLOW='\033[1;33m'
_BLUE='\033[0;34m'
_BOLD='\033[1m'
_RESET='\033[0m'

log_info()    { printf "${_BLUE}[INFO]${_RESET}  %s\n" "$*"; }
log_warn()    { printf "${_YELLOW}[WARN]${_RESET}  %s\n" "$*"; }
log_error()   { printf "${_RED}[ERROR]${_RESET} %s\n" "$*" >&2; }
log_success() { printf "${_GREEN}[OK]${_RESET}    %s\n" "$*"; }
log_skip()    { printf "${_YELLOW}[SKIP]${_RESET}  %s\n" "$*"; }
log_dry()     { printf "${_BLUE}[DRY]${_RESET}   %s\n" "$*"; }

# ── Mode checks ──────────────────────────────────────────────────────────────
is_dry_run() { [[ "${BOOTSTRAP_DRY_RUN}" == "1" ]]; }
is_force()   { [[ "${BOOTSTRAP_FORCE}" == "1" ]]; }
is_yes()     { [[ "${BOOTSTRAP_YES}" == "1" ]]; }

is_skipped() {
    local component="$1"
    local s
    IFS=',' read -ra _skip_list <<< "${BOOTSTRAP_SKIP:-}"
    for s in "${_skip_list[@]+"${_skip_list[@]}"}"; do
        [[ "${s// /}" == "$component" ]] && return 0
    done
    return 1
}

# ── OS / arch detection ───────────────────────────────────────────────────────
detect_os() {
    case "$(uname -s)" in
        Darwin) printf "macos" ;;
        Linux)  printf "linux" ;;
        *)      printf "unsupported" ;;
    esac
}

detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64)   printf "x86_64" ;;
        arm64|aarch64)  printf "arm64" ;;
        *)              printf "$(uname -m)" ;;
    esac
}

# ── Dependency checks ─────────────────────────────────────────────────────────
check_command() { command -v "$1" >/dev/null 2>&1; }

require_command() {
    local cmd="$1"
    local hint="${2:-}"
    if ! check_command "$cmd"; then
        log_error "Required command not found: ${cmd}"
        [[ -n "$hint" ]] && log_error "  Install: ${hint}"
        return 1
    fi
}

# ── Backup ────────────────────────────────────────────────────────────────────
# Creates a timestamped backup of a file. Prints the backup path.
backup_file() {
    local path="$1"
    if [[ -e "$path" ]]; then
        local backup
        backup="${path}.bak.$(date +%Y%m%d_%H%M%S)"
        if is_dry_run; then
            log_dry "Would backup: ${path} → ${backup}"
        else
            cp -a "$path" "$backup"
            log_info "Backed up: ${path} → ${backup}"
        fi
        printf "%s" "$backup"
    fi
}

# ── Confirmation prompt ───────────────────────────────────────────────────────
# Returns 0 (proceed) or 1 (skip). In --yes mode always returns 0.
# Usage: ask_confirm <id> <Display Name> <description> <what it modifies>
ask_confirm() {
    local id="$1"
    local name="$2"
    local description="$3"
    local changes="$4"

    printf "\n${_BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${_RESET}\n"
    printf "${_BOLD}  %s${_RESET}\n" "$name"
    printf "  What:    %s\n" "$description"
    printf "  Modifies: %s\n" "$changes"
    printf "  To skip: --skip %s\n" "$id"
    printf "${_BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${_RESET}\n\n"

    if is_yes; then
        log_info "--yes mode: proceeding with ${name}"
        return 0
    fi

    local answer
    printf "  Install %s? [Y/n] " "$name"
    read -r answer < /dev/tty || true
    case "${answer,,}" in
        n|no) return 1 ;;
        *) return 0 ;;   # default = yes (empty input or any other answer)
    esac
}

# ── Result tracking ───────────────────────────────────────────────────────────
RESULTS_FILE="${BOOTSTRAP_LOG_DIR}/results.tsv"

record_result() {
    local component="$1"
    local status="$2"   # OK | FAILED | SKIPPED | DECLINED
    local details="${3:-}"
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    mkdir -p "$(dirname "${RESULTS_FILE}")"
    printf "%s\t%-25s\t%s\t%s\n" "$ts" "$component" "$status" "$details" >> "${RESULTS_FILE}"
}

# ── Logging setup ─────────────────────────────────────────────────────────────
setup_logging() {
    mkdir -p "${BOOTSTRAP_LOG_DIR}"
    log_info "Log dir: ${BOOTSTRAP_LOG_DIR}"
}
