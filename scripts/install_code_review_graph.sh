#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=../lib/common.sh
source "$(dirname "$0")/../lib/common.sh"

id="code-review-graph"
name="code-review-graph"
description="Structural knowledge graph for code reviews. Computes blast-radius and impact analysis via Tree-sitter AST parsing"
changes="Installs code-review-graph Python package, adds MCP server entry to ~/.claude.json"

if is_skipped "$id"; then
    record_result "$id" "SKIPPED" "via --skip"
    exit 0
fi

if check_command code-review-graph && ! is_force; then
    log_info "code-review-graph already installed"
    record_result "$id" "SKIPPED" "already installed"
    exit 0
fi

ask_confirm "$id" "$name" "$description" "$changes" || { record_result "$id" "DECLINED"; exit 0; }

if check_command pipx; then
    installer="pipx"
elif check_command pip3; then
    installer="pip3"
else
    log_error "Neither pipx nor pip3 found. Install one first:"
    log_error "  macOS: brew install pipx  OR  pip3 install pipx"
    log_error "  Linux: apt install pipx   OR  pip3 install pipx"
    record_result "$id" "FAILED" "pipx and pip3 not found"
    exit 1
fi

if is_dry_run; then
    if [[ "$installer" == "pipx" ]]; then
        log_dry "Would run: pipx install code-review-graph"
    else
        log_dry "Would run: pip3 install --user code-review-graph"
    fi
    exit 0
fi

if [[ "$installer" == "pipx" ]]; then
    pipx install code-review-graph
else
    pip3 install --user code-review-graph
    log_warn "Installed via pip3 --user. Ensure ~/.local/bin is in your PATH."
fi

export PATH="$HOME/.local/bin:$PATH"

if ! check_command code-review-graph; then
    log_error "code-review-graph not found in PATH after install"
    record_result "$id" "FAILED" "code-review-graph command not found after install"
    exit 1
fi

if [[ -f "$HOME/.claude.json" ]]; then
    backup_file "$HOME/.claude.json"
fi

code-review-graph install

if ! code-review-graph --version 2>/dev/null && ! code-review-graph status 2>/dev/null; then
    log_error "code-review-graph verification failed"
    record_result "$id" "FAILED" "verification command failed"
    exit 1
fi

record_result "$id" "OK"
log_success "code-review-graph installed and configured for Claude Code MCP"
