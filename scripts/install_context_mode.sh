#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=../lib/common.sh
source "$(dirname "$0")/../lib/common.sh"

id="context-mode"
name="context-mode"
description="Claude Code plugin that prevents context window overflow. Provides sandbox tools for token-efficient operations"
changes="Adds MCP server to ~/.claude.json or installs plugin via Claude Code plugin system"

if is_skipped "$id"; then
    record_result "$id" "SKIPPED" "via --skip"
    exit 0
fi

if grep -q '"context-mode"' "${HOME}/.claude.json" 2>/dev/null; then
    if ! is_force; then
        log_skip "context-mode already configured in ~/.claude.json"
        record_result "$id" "SKIPPED" "already configured"
        exit 0
    fi
fi

ask_confirm "$id" "$name" "$description" "$changes" || { record_result "$id" "DECLINED"; exit 0; }

if ! check_command claude; then
    log_error "claude CLI is required but not found."
    record_result "$id" "FAILED" "claude CLI not found"
    exit 1
fi

if ! check_command npx && ! check_command npm; then
    log_error "npx or npm is required but not found."
    record_result "$id" "FAILED" "npm/npx not found"
    exit 1
fi

if is_dry_run; then
    log_dry "Would backup: ~/.claude.json (if exists)"
    log_dry "Would try: claude plugin marketplace add mksglu/context-mode"
    log_dry "Would try: claude plugin install context-mode@context-mode"
    log_dry "Fallback:  claude mcp add context-mode -- npx -y context-mode"
    exit 0
fi

if [[ -f "${HOME}/.claude.json" ]]; then
    backup_file "${HOME}/.claude.json"
fi

_install_method=""

if claude plugin --help >/dev/null 2>&1; then
    if claude plugin marketplace add mksglu/context-mode 2>/dev/null \
        && claude plugin install context-mode@context-mode 2>/dev/null; then
        _install_method="Claude Code plugin system"
    fi
fi

if [[ -z "$_install_method" ]]; then
    if ! claude mcp add context-mode -- npx -y context-mode; then
        log_error "Failed to add context-mode MCP server."
        record_result "$id" "FAILED" "mcp add failed"
        exit 1
    fi
    _install_method="MCP server (claude mcp add)"
fi

log_info "Installed via: ${_install_method}"

if grep -q '"context-mode"' "${HOME}/.claude.json" 2>/dev/null \
    || claude mcp list 2>/dev/null | grep -q "context-mode"; then
    log_info "Note: Full plugin features (slash commands, hooks) require restarting Claude Code"
    record_result "$id" "OK" "installed via ${_install_method}"
    log_success "context-mode installed successfully"
else
    log_warn "context-mode not found in claude mcp list or ~/.claude.json after install"
    record_result "$id" "FAILED" "verification failed"
    exit 1
fi
