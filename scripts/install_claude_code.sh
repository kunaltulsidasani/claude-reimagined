#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=../lib/common.sh
source "$(dirname "$0")/../lib/common.sh"

id="claude-code"
name="Claude Code"
description="Anthropic's official AI coding assistant CLI"
changes="Installs claude CLI via official install script, creates ~/.claude/ config directory"

if is_skipped "$id"; then
    record_result "$id" "SKIPPED" "via --skip"
    exit 0
fi

if check_command claude && ! is_force; then
    log_info "Claude Code already installed: $(claude --version 2>/dev/null | head -1)"
    record_result "$id" "SKIPPED" "already installed"
    exit 0
fi

ask_confirm "$id" "$name" "$description" "$changes" || { record_result "$id" "DECLINED"; exit 0; }

if ! check_command curl; then
    log_error "curl is required but not found."
    log_error "  macOS: brew install curl"
    log_error "  Linux: sudo apt install curl  OR  sudo dnf install curl"
    record_result "$id" "FAILED" "curl not found"
    exit 1
fi

if is_dry_run; then
    log_dry "Would run: curl -fsSL https://claude.ai/install.sh | bash"
    exit 0
fi

curl -fsSL https://claude.ai/install.sh | bash

# Reload PATH in case install added a new bin dir
export PATH="${HOME}/.local/bin:${HOME}/.cargo/bin:${PATH}"

if ! check_command claude; then
    log_error "Claude Code installation verification failed"
    record_result "$id" "FAILED" "claude command not found after install"
    exit 1
fi

record_result "$id" "OK" "$(claude --version 2>/dev/null | head -1)"
log_success "Claude Code installed"
