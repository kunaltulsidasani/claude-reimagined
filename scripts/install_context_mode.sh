#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=../lib/common.sh
source "$(dirname "$0")/../lib/common.sh"

id="context-mode"
name="context-mode"
description="Claude Code plugin that prevents context window overflow. Provides sandbox tools for token-efficient operations"
changes="Installs context-mode plugin via Claude Code plugin system"

if is_skipped "$id"; then
    record_result "$id" "SKIPPED" "via --skip"
    exit 0
fi

_already_installed() {
    ls "${HOME}/.claude/plugins/"*context-mode* >/dev/null 2>&1 \
        || grep -qi "context-mode" "${HOME}/.claude/settings.json" 2>/dev/null \
        || grep -q '"context-mode"' "${HOME}/.claude.json" 2>/dev/null \
        || (check_command claude && claude mcp list 2>/dev/null | grep -qi "context-mode")
}

if _already_installed && ! is_force; then
    log_skip "context-mode already installed"
    record_result "$id" "SKIPPED" "already installed"
    exit 0
fi

ask_confirm "$id" "$name" "$description" "$changes" || { record_result "$id" "DECLINED"; exit 0; }

if ! check_command claude; then
    log_error "claude CLI is required but not found."
    record_result "$id" "FAILED" "claude CLI not found"
    exit 1
fi

if is_dry_run; then
    log_dry "Would try: claude plugin marketplace add mksglu/context-mode"
    log_dry "Would try: claude plugin install context-mode@context-mode"
    exit 0
fi

_install_method=""

if claude plugin --help >/dev/null 2>&1; then
    if claude plugin marketplace add mksglu/context-mode 2>/dev/null \
        && claude plugin install context-mode@context-mode 2>/dev/null; then
        _install_method="Claude Code plugin system"
    fi
fi

if [[ -z "$_install_method" ]]; then
    log_error "Failed to install context-mode via Claude Code plugin system."
    log_error "Install manually: claude plugin marketplace add mksglu/context-mode"
    record_result "$id" "FAILED" "plugin install failed"
    exit 1
fi

log_info "Installed via: ${_install_method}"

if _already_installed; then
    log_info "Note: Restart Claude Code to activate plugin hooks and slash commands"
    record_result "$id" "OK" "installed via ${_install_method}"
    log_success "context-mode installed successfully"
else
    log_warn "context-mode not detected after install — restart Claude Code and verify"
    record_result "$id" "OK" "installed (restart required to verify)"
    log_success "context-mode installed (restart Claude Code to activate)"
fi
