#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

COMPONENT_ID="statusline"
COMPONENT_NAME="statusline.sh"
COMPONENT_DESC="Custom Claude Code statusline integration — shows context info in Claude Code's status bar"
COMPONENT_CHANGES="Copies statusline.sh to ~/.claude/statusline.sh, sets executable bit, updates ~/.claude/settings.json statusLine entry"

if is_skipped "${COMPONENT_ID}"; then
    record_result "${COMPONENT_ID}" "SKIPPED" "skipped via flag"
    exit 0
fi

SEARCH_PATHS=(
    "${SCRIPT_DIR}/../statusline.sh"
    "${HOME}/.config/claude/statusline.sh"
    "./statusline.sh"
)

source_path=""
for candidate in "${SEARCH_PATHS[@]}"; do
    if [[ -f "${candidate}" ]]; then
        source_path="$(cd "$(dirname "${candidate}")" && pwd)/$(basename "${candidate}")"
        break
    fi
done

if [[ -z "${source_path}" ]]; then
    log_warn "statusline.sh not found in search paths"
    record_result "${COMPONENT_ID}" "SKIPPED" "statusline.sh not found in search paths"
    exit 0
fi

log_info "Found statusline.sh at: ${source_path}"

if ! ask_confirm "${COMPONENT_ID}" "${COMPONENT_NAME}" "${COMPONENT_DESC}" "${COMPONENT_CHANGES}"; then
    record_result "${COMPONENT_ID}" "DECLINED" "user declined"
    exit 0
fi

mkdir -p "${HOME}/.claude"
dest="${HOME}/.claude/statusline.sh"

if [[ "${source_path}" != "${dest}" ]]; then
    if [[ -f "${dest}" ]]; then
        backup_file "${dest}"
    fi
    if is_dry_run; then
        log_dry "Would copy ${source_path} → ${dest}"
    else
        cp "${source_path}" "${dest}"
    fi
fi

if ! is_dry_run; then
    chmod +x "${dest}"
fi

if check_command "shellcheck" && ! is_dry_run; then
    if shellcheck "${dest}"; then
        log_info "shellcheck: ${dest} passed"
    else
        log_warn "shellcheck reported issues in ${dest} (non-fatal)"
    fi
fi

settings_json="${HOME}/.claude/settings.json"

if ! is_dry_run; then
    if [[ -f "${settings_json}" ]]; then
        backup_file "${settings_json}"
    fi

    if check_command "python3"; then
        python3 - "${settings_json}" "${HOME}/.claude/statusline.sh" <<'PYEOF'
import sys, json, os

settings_file = sys.argv[1]
statusline_path = sys.argv[2]

if os.path.exists(settings_file):
    with open(settings_file, "r") as f:
        data = json.load(f)
else:
    data = {}

data["statusLine"] = statusline_path

with open(settings_file, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PYEOF
        log_info "Updated ${settings_json} with statusLine entry"
    elif check_command "jq"; then
        tmp=$(mktemp)
        if [[ -f "${settings_json}" ]]; then
            jq --arg v "${HOME}/.claude/statusline.sh" '. + {statusLine: $v}' "${settings_json}" > "${tmp}"
        else
            jq -n --arg v "${HOME}/.claude/statusline.sh" '{statusLine: $v}' > "${tmp}"
        fi
        mv "${tmp}" "${settings_json}"
        log_info "Updated ${settings_json} with statusLine entry (via jq)"
    else
        log_warn "Neither python3 nor jq found. Add manually to ${settings_json}:"
        log_warn '  "statusLine": "'"${HOME}/.claude/statusline.sh"'"'
    fi
else
    log_dry "Would update ${settings_json} with statusLine: ${HOME}/.claude/statusline.sh"
fi

record_result "${COMPONENT_ID}" "OK"
log_success "statusline installed successfully"
