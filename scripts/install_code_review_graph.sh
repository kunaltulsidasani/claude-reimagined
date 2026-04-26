#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=../lib/common.sh
source "$(dirname "$0")/../lib/common.sh"

id="code-review-graph"
name="code-review-graph"
description="Structural knowledge graph for code reviews. Computes blast-radius and impact analysis via Tree-sitter AST parsing"
changes="Installs code-review-graph via uv tool install"

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

if ! check_command uv; then
    log_error "uv is required but not found."
    log_error "  Install: curl -LsSf https://astral.sh/uv/install.sh | sh"
    record_result "$id" "FAILED" "uv not found"
    exit 1
fi

if is_dry_run; then
    log_dry "Would run: uv tool install code-review-graph"
    exit 0
fi

uv tool install code-review-graph

export PATH="${HOME}/.local/bin:${PATH}"

if ! check_command code-review-graph; then
    log_error "code-review-graph not found in PATH after install"
    record_result "$id" "FAILED" "code-review-graph command not found after install"
    exit 1
fi

log_info "Note: Run 'code-review-graph install' inside each repo to enable MCP integration for that project."

record_result "$id" "OK"
log_success "code-review-graph installed"
