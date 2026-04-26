#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

COMPONENT_ID="caveman"
COMPONENT_NAME="caveman"
COMPONENT_DESC="Claude Code plugin that enforces terse response style, saving ~70% of response tokens. Provides caveman-commit, caveman-review, caveman-compress, caveman-help skills"
COMPONENT_CHANGES="Installs Claude Code plugin via plugin marketplace, adds SessionStart hook, installs skills to ~/.claude/plugins/"

CAVEMAN_HOOKS_URL="https://raw.githubusercontent.com/JuliusBrussee/caveman/main/hooks/install.sh"

_caveman_installed() {
    local plugins_dir="${HOME}/.claude/plugins"
    local settings_file="${HOME}/.claude/settings.json"

    if [[ -d "${plugins_dir}" ]]; then
        local entry
        for entry in "${plugins_dir}"/*[Cc][Aa][Vv][Ee][Mm][Aa][Nn]*; do
            [[ -e "$entry" ]] && return 0
        done
    fi

    if [[ -f "${settings_file}" ]] && grep -qi "caveman" "${settings_file}" 2>/dev/null; then
        return 0
    fi

    return 1
}

if is_skipped "${COMPONENT_ID}"; then
    record_result "${COMPONENT_ID}" "SKIPPED"
    log_skip "${COMPONENT_NAME}: skipped via --skip flag"
    exit 0
fi

if _caveman_installed && ! is_force; then
    record_result "${COMPONENT_ID}" "SKIPPED" "already installed"
    log_skip "${COMPONENT_NAME}: already installed (use --force to reinstall)"
    exit 0
fi

if ! ask_confirm "${COMPONENT_ID}" "${COMPONENT_NAME}" "${COMPONENT_DESC}" "${COMPONENT_CHANGES}"; then
    record_result "${COMPONENT_ID}" "DECLINED"
    log_skip "${COMPONENT_NAME}: declined by user"
    exit 0
fi

if ! check_command "claude"; then
    log_error "Required command not found: claude"
    log_error "  Install Claude Code CLI first: https://claude.ai/code"
    record_result "${COMPONENT_ID}" "FAILED" "claude CLI not found"
    exit 1
fi

if is_dry_run; then
    log_dry "claude plugin marketplace add JuliusBrussee/caveman"
    log_dry "claude plugin install caveman@caveman"
    log_dry "Would verify caveman in ~/.claude/plugins/ or ~/.claude/settings.json"
    exit 0
fi

plugin_ok=0

log_info "Installing caveman via plugin marketplace..."
if claude plugin marketplace add JuliusBrussee/caveman 2>&1 && \
   claude plugin install caveman@caveman 2>&1; then
    plugin_ok=1
else
    log_warn "Plugin install failed, falling back to standalone hooks"
    log_info "Fetching: ${CAVEMAN_HOOKS_URL}"
    bash <(curl -s "${CAVEMAN_HOOKS_URL}")
fi

if ! _caveman_installed; then
    if [[ "${plugin_ok}" -eq 0 ]]; then
        log_error "Caveman installation could not be verified"
        record_result "${COMPONENT_ID}" "FAILED" "not found in plugins dir or settings.json after install"
        exit 1
    fi
    log_warn "Caveman not found in standard locations, but plugin commands succeeded"
fi

log_info "Note: Caveman activates automatically on next Claude Code session"
record_result "${COMPONENT_ID}" "OK"
log_success "caveman installed"
