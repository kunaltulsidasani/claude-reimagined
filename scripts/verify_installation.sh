#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

RESULTS_FILE="${BOOTSTRAP_LOG_DIR}/results.tsv"

# ── Helpers ───────────────────────────────────────────────────────────────────

_ok=0
_fail=0
_skip=0

_was_skipped_or_declined() {
    local component="$1"
    [[ -f "${RESULTS_FILE}" ]] || return 1
    grep -qE "	${component}[[:space:]]*	(SKIPPED|DECLINED)	" "${RESULTS_FILE}" 2>/dev/null
}

_print_row() {
    local status="$1"
    local name="$2"
    local detail="$3"
    case "$status" in
        OK)   printf "${_GREEN}[OK]${_RESET}   %-25s %s\n" "$name" "$detail"; (( _ok   += 1 )) ;;
        FAIL) printf "${_RED}[FAIL]${_RESET} %-25s %s\n"  "$name" "$detail"; (( _fail += 1 )) ;;
        SKIP) printf "${_YELLOW}[SKIP]${_RESET} %-25s %s\n" "$name" "$detail"; (( _skip  += 1 )) ;;
    esac
}

_check() {
    local id="$1"
    local name="$2"
    # caller sets _status and _detail before calling _check
    if _was_skipped_or_declined "$id"; then
        _print_row SKIP "$name" "(skipped/declined during bootstrap)"
        return
    fi
    if [[ "$_status" == "ok" ]]; then
        _print_row OK "$name" "$_detail"
    else
        _print_row FAIL "$name" "$_detail"
    fi
}

# ── Component checks ──────────────────────────────────────────────────────────

check_claude_code() {
    local _status _detail
    if check_command claude; then
        _detail="$(claude --version 2>/dev/null | head -1 || true)"
        _status="ok"
    else
        _status="fail"; _detail="claude not found in PATH"
    fi
    _check "claude-code" "claude-code"
}

check_rtk() {
    local _status _detail
    if ! check_command rtk; then
        _status="fail"; _detail="rtk not found in PATH"
    elif ! rtk gain >/dev/null 2>&1; then
        _status="fail"; _detail="rtk found but 'rtk gain' failed (wrong RTK binary?)"
    else
        _detail="$(rtk --version 2>/dev/null | head -1 || true)"
        _status="ok"
    fi
    _check "rtk" "rtk"
}

check_code_review_graph() {
    local _status _detail
    if check_command code-review-graph; then
        _detail="$(code-review-graph --version 2>/dev/null | head -1 || true)"
        _status="ok"
    else
        _status="fail"; _detail="code-review-graph not found in PATH"
    fi
    _check "code-review-graph" "code-review-graph"
}

check_context_mode() {
    local _status _detail
    local found=0
    if ls "${HOME}/.claude/plugins/"*context-mode* >/dev/null 2>&1; then
        found=1; _detail="${HOME}/.claude/plugins/ (plugin dir)"
    fi
    if [[ "$found" == "0" ]] && [[ -f "${HOME}/.claude/settings.json" ]]; then
        grep -qi "context-mode" "${HOME}/.claude/settings.json" 2>/dev/null && found=1
        [[ "$found" == "1" ]] && _detail="${HOME}/.claude/settings.json"
    fi
    if [[ "$found" == "0" ]] && [[ -f "${HOME}/.claude.json" ]]; then
        grep -q '"context-mode"' "${HOME}/.claude.json" 2>/dev/null && found=1
        [[ "$found" == "1" ]] && _detail="${HOME}/.claude.json"
    fi
    if [[ "$found" == "1" ]]; then
        _status="ok"
    else
        _status="fail"; _detail="context-mode not found in plugins dir, settings.json, or ~/.claude.json"
    fi
    _check "context-mode" "context-mode"
}

check_caveman() {
    local _status _detail
    local found=0
    if ls "${HOME}/.claude/plugins/"*caveman* >/dev/null 2>&1; then
        found=1; _detail="${HOME}/.claude/plugins/ (plugin dir)"
    fi
    if [[ "$found" == "0" ]] && [[ -f "${HOME}/.claude/settings.json" ]]; then
        grep -qi "caveman" "${HOME}/.claude/settings.json" 2>/dev/null && found=1
        [[ "$found" == "1" ]] && _detail="${HOME}/.claude/settings.json (hook)"
    fi
    if [[ "$found" == "1" ]]; then
        _status="ok"
    else
        _status="fail"; _detail="caveman not found in plugins dir or settings.json"
    fi
    _check "caveman" "caveman"
}

check_statusline() {
    local _status _detail
    local path="${HOME}/.claude/statusline.sh"
    if [[ -x "$path" ]]; then
        _status="ok"; _detail="$path"
    elif [[ -f "$path" ]]; then
        _status="fail"; _detail="${path} exists but is not executable"
    else
        _status="fail"; _detail="${path} not found"
    fi
    _check "statusline" "statusline"
}

check_subagent_router() {
    local _status _detail
    local path="${HOME}/.claude/hooks/subagent-model-router.sh"
    if [[ ! -x "$path" ]]; then
        _status="fail"; _detail="${path} not found or not executable"
    elif ! grep -q "subagent-model-router" "${HOME}/.claude/settings.json" 2>/dev/null; then
        _status="fail"; _detail="hook file exists but not registered in settings.json"
    else
        _status="ok"; _detail="$path"
    fi
    _check "subagent-router" "subagent-model-router"
}

check_claude_md() {
    local _status _detail
    local path="${HOME}/.claude/CLAUDE.md"
    if [[ -f "$path" ]]; then
        _status="ok"; _detail="$path"
    else
        _status="fail"; _detail="${path} not found"
    fi
    _check "claude-md" "CLAUDE.md"
}

check_settings() {
    local _status _detail
    local path="${HOME}/.claude/settings.json"
    if [[ -f "$path" ]]; then
        _status="ok"; _detail="$path"
    else
        _status="fail"; _detail="${path} not found"
    fi
    _check "settings" "settings"
}

# ── Main ──────────────────────────────────────────────────────────────────────

printf "\n${_BOLD}━━━ Installation Verification ━━━━━━━━━━━━━━━━━━━━━━━━━━━${_RESET}\n\n"

if is_dry_run; then
    log_info "Dry-run mode: skipping post-install verification (no files were created)"
    exit 0
fi

check_claude_code
check_rtk
check_code_review_graph
check_context_mode
check_caveman
check_statusline
check_subagent_router
check_claude_md
check_settings

total=$(( _ok + _fail + _skip ))
printf "\n${_BOLD}━━━ Summary ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${_RESET}\n"
printf "  %d/%d components OK  (%d skipped, %d failed)\n\n" "$_ok" "$total" "$_skip" "$_fail"

if [[ "$_fail" -gt 0 ]]; then
    exit 1
fi
exit 0
