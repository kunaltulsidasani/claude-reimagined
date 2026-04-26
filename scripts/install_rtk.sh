#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=../lib/common.sh
source "$(dirname "$0")/../lib/common.sh"

id="rtk"
name="RTK (Token Killer)"
description="Token-efficient CLI proxy for Claude Code. Wraps git/npm/test commands, saves 60-90% of tokens"
changes="~/.claude/hooks/rtk-rewrite.sh, patches ~/.claude/settings.json (with backup), adds @RTK.md to ~/.claude/CLAUDE.md"

if is_skipped "$id"; then
    record_result "$id" "SKIPPED" "via --skip"
    exit 0
fi

if check_command rtk; then
    if rtk gain >/dev/null 2>&1; then
        if ! is_force; then
            log_info "RTK already installed: $(rtk --version 2>/dev/null | head -1)"
            record_result "$id" "SKIPPED" "already installed"
            exit 0
        fi
    else
        log_warn "rtk is installed but 'rtk gain' failed — wrong RTK detected."
        log_warn "You have 'reachingforthejack/rtk' (Rust Type Kit), not rtk-ai/rtk (Token Killer)."
        log_warn "Uninstall the wrong RTK first, then re-run this script:"
        log_warn "  cargo uninstall rtk"
        log_warn "  OR: brew uninstall rtk"
        record_result "$id" "FAILED" "wrong rtk installed - uninstall first"
        exit 1
    fi
fi

ask_confirm "$id" "$name" "$description" "$changes" || { record_result "$id" "DECLINED"; exit 0; }

if ! check_command curl; then
    log_error "curl is required but not found."
    record_result "$id" "FAILED" "curl not found"
    exit 1
fi

if ! check_command sh; then
    log_error "sh is required but not found."
    record_result "$id" "FAILED" "sh not found"
    exit 1
fi

if is_dry_run; then
    if check_command brew; then
        log_dry "Would run: brew install rtk"
    else
        log_dry "Would run: curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh"
    fi
    log_dry "Would run: rtk init -g"
    exit 0
fi

if check_command brew; then
    log_info "Installing via Homebrew"
    if ! brew install rtk; then
        log_error "brew install rtk failed."
        record_result "$id" "FAILED" "brew install returned non-zero"
        exit 1
    fi
else
    log_info "Installing from: https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh"
    if ! curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh; then
        log_error "RTK installation failed."
        record_result "$id" "FAILED" "install script returned non-zero"
        exit 1
    fi
fi

if [[ -f "${HOME}/.cargo/env" ]]; then
    # shellcheck source=/dev/null
    source "${HOME}/.cargo/env"
fi
export PATH="${HOME}/.local/bin:${HOME}/.cargo/bin:${PATH}"

if ! rtk init -g; then
    log_error "rtk init -g failed."
    record_result "$id" "FAILED" "rtk init failed"
    exit 1
fi

log_info "RTK init configuration:"
rtk init --show 2>/dev/null || true

if ! check_command rtk; then
    log_error "rtk command not found after installation."
    record_result "$id" "FAILED" "rtk not found after install"
    exit 1
fi

if ! rtk gain >/dev/null 2>&1; then
    log_error "rtk gain failed — installation may be incomplete or wrong RTK was installed."
    record_result "$id" "FAILED" "rtk gain failed after install"
    exit 1
fi

_rtk_version="$(rtk --version 2>/dev/null | head -1)"
record_result "$id" "OK" "${_rtk_version}"
log_success "RTK (Token Killer) installed: ${_rtk_version}"
