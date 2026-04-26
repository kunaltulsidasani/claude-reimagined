#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

# ── Defaults ──────────────────────────────────────────────────────────────────
export BOOTSTRAP_DRY_RUN="${BOOTSTRAP_DRY_RUN:-0}"
export BOOTSTRAP_FORCE="${BOOTSTRAP_FORCE:-0}"
export BOOTSTRAP_YES="${BOOTSTRAP_YES:-0}"
export BOOTSTRAP_SKIP="${BOOTSTRAP_SKIP:-}"
export BOOTSTRAP_CLEAN="${BOOTSTRAP_CLEAN:-0}"
export BOOTSTRAP_LOG_DIR="${HOME}/.claude-bootstrap/logs"

# ── Usage ─────────────────────────────────────────────────────────────────────
usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --dry-run        Show what would happen without installing anything
  --force          Reinstall even if already installed
  --yes            Auto-approve all confirmation prompts
  --skip <ids>         Skip components (comma-separated, e.g. --skip rtk,caveman)
  --skills-only <ids>  Install only specific skills (comma-separated, e.g. --skills-only python-pro,golang-pro)
  --clean              Remove ~/.claude before installing (fresh start)
  --help               Show this help

Examples:
  ./bootstrap.sh
  ./bootstrap.sh --dry-run
  ./bootstrap.sh --force
  ./bootstrap.sh --yes
  ./bootstrap.sh --clean --yes
  ./bootstrap.sh --skip rtk,caveman --yes
  ./bootstrap.sh --skills-only python-pro,golang-pro,postgres-pro
EOF
}

# ── Flag parsing ──────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) export BOOTSTRAP_DRY_RUN=1; shift ;;
        --force)   export BOOTSTRAP_FORCE=1;   shift ;;
        --yes)     export BOOTSTRAP_YES=1;     shift ;;
        --skip)
            shift
            [[ $# -gt 0 ]] || { log_error "--skip requires an argument"; exit 1; }
            if [[ -n "${BOOTSTRAP_SKIP}" ]]; then
                export BOOTSTRAP_SKIP="${BOOTSTRAP_SKIP},$1"
            else
                export BOOTSTRAP_SKIP="$1"
            fi
            shift
            ;;
        --skills-only)
            shift
            [[ $# -gt 0 ]] || { log_error "--skills-only requires an argument"; exit 1; }
            export SKILLS_ONLY="$1"
            shift
            ;;
        --clean)   export BOOTSTRAP_CLEAN=1;  shift ;;
        --help|-h) usage; exit 0 ;;
        *) log_error "Unknown flag: $1"; usage; exit 1 ;;
    esac
done

# ── OS check ──────────────────────────────────────────────────────────────────
OS="$(detect_os)"
ARCH="$(detect_arch)"

if [[ "$OS" == "unsupported" ]]; then
    log_error "Unsupported OS: $(uname -s). Only macOS and Linux are supported."
    exit 1
fi

# ── Clean ─────────────────────────────────────────────────────────────────────
if [[ "${BOOTSTRAP_CLEAN}" == "1" ]]; then
    if [[ -d "${HOME}/.claude" ]]; then
        if ! is_yes; then
            printf "${_RED}WARNING:${_RESET} --clean will permanently delete %s\n" "${HOME}/.claude"
            printf "Continue? [y/N] "
            read -r _clean_confirm
            [[ "$_clean_confirm" =~ ^[Yy]$ ]] || { log_info "Aborted."; exit 0; }
        fi
        if is_dry_run; then
            log_dry "Would run: rm -rf ${HOME}/.claude"
        else
            log_info "Removing ${HOME}/.claude"
            rm -rf "${HOME}/.claude"
        fi
    else
        log_info "--clean: ${HOME}/.claude does not exist, nothing to remove"
    fi
fi

# ── Banner ────────────────────────────────────────────────────────────────────
_mode=""
is_dry_run && _mode="${_mode} dry-run"
is_force   && _mode="${_mode} force"
is_yes     && _mode="${_mode} yes"
[[ "${BOOTSTRAP_CLEAN}" == "1" ]] && _mode="${_mode} clean"
[[ -z "$_mode" ]] && _mode=" interactive"

printf "\n${_BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${_RESET}\n"
printf "${_BOLD}  claude-reimagined bootstrap${_RESET}\n"
printf "  OS:      %s (%s)\n" "$OS" "$ARCH"
printf "  Mode:   %s\n" "$_mode"
printf "  Logs:    %s\n" "${BOOTSTRAP_LOG_DIR}"
[[ -n "${BOOTSTRAP_SKIP}" ]] && printf "  Skip:    %s\n" "${BOOTSTRAP_SKIP}"
printf "${_BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${_RESET}\n\n"

# ── Setup ─────────────────────────────────────────────────────────────────────
setup_logging
# Clear results from previous runs so verify reads only this run's state
: > "${BOOTSTRAP_LOG_DIR}/results.tsv"
chmod +x scripts/*.sh

# ── Run a script, capturing exit code ─────────────────────────────────────────
_verify_exit=0

run_script() {
    local script="$1"
    local is_critical="${2:-0}"
    log_info "Running: ${script}"
    if bash "$script"; then
        return 0
    else
        local code=$?
        log_error "Script failed (exit ${code}): ${script}"
        if [[ "$is_critical" == "1" ]]; then
            log_error "Aborting: ${script} is a required dependency."
            exit 1
        fi
        return 0
    fi
}

# ── Script execution order ────────────────────────────────────────────────────
run_script "scripts/install_deps.sh"         1
run_script "scripts/install_claude_code.sh"  1
run_script "scripts/install_rtk.sh"
run_script "scripts/install_code_review_graph.sh"
run_script "scripts/install_context_mode.sh"
run_script "scripts/install_caveman.sh"
run_script "scripts/install_statusline.sh"
run_script "scripts/install_subagent_router.sh"
run_script "scripts/install_pre_compact.sh"
run_script "scripts/install_skills.sh"

# ── Final verify ──────────────────────────────────────────────────────────────
printf "\n"
if bash "scripts/verify_installation.sh"; then
    _verify_exit=0
else
    _verify_exit=1
fi

# ── Print results summary from TSV ────────────────────────────────────────────
RESULTS_FILE="${BOOTSTRAP_LOG_DIR}/results.tsv"
if [[ -f "${RESULTS_FILE}" ]]; then
    printf "\n${_BOLD}━━━ Bootstrap Results ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${_RESET}\n"
    while IFS=$'\t' read -r ts component status details; do
        case "$status" in
            OK)      printf "${_GREEN}[OK]${_RESET}      %-25s %s\n" "$component" "$details" ;;
            FAILED)  printf "${_RED}[FAILED]${_RESET}  %-25s %s\n" "$component" "$details" ;;
            SKIPPED) printf "${_YELLOW}[SKIPPED]${_RESET} %-25s %s\n" "$component" "$details" ;;
            DECLINED)printf "${_YELLOW}[DECLINED]${_RESET} %-25s %s\n" "$component" "$details" ;;
            *)       printf "  %-10s %-25s %s\n" "$status" "$component" "$details" ;;
        esac
    done < "${RESULTS_FILE}"
    printf "${_BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${_RESET}\n\n"
fi

exit "$_verify_exit"
