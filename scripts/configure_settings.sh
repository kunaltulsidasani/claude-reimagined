#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

COMPONENT_ID="settings-config"
COMPONENT_NAME="settings.json"
COMPONENT_DESC="Installs Claude Code settings — UX preferences, hooks structure, statusLine, known marketplaces"
COMPONENT_CHANGES="Copies configs/settings.json to ~/.claude/settings.json (with backup). Replaces existing file."

if is_skipped "${COMPONENT_ID}"; then
    record_result "${COMPONENT_ID}" "SKIPPED" "skipped via flag"
    exit 0
fi

SOURCE="${SCRIPT_DIR}/../configs/settings.json"
DEST="${HOME}/.claude/settings.json"

if [[ ! -f "${SOURCE}" ]]; then
    log_warn "configs/settings.json not found in repo"
    record_result "${COMPONENT_ID}" "SKIPPED" "source not found"
    exit 0
fi

if [[ -f "${DEST}" ]] && ! is_force; then
    log_skip "settings.json already exists (use --force to overwrite)"
    record_result "${COMPONENT_ID}" "SKIPPED" "already exists"
    exit 0
fi

if ! ask_confirm "${COMPONENT_ID}" "${COMPONENT_NAME}" "${COMPONENT_DESC}" "${COMPONENT_CHANGES}"; then
    record_result "${COMPONENT_ID}" "DECLINED" "user declined"
    exit 0
fi

if is_dry_run; then
    log_dry "Would copy configs/settings.json → ${DEST} (substituting __HOME__ → ${HOME})"
    exit 0
fi

mkdir -p "${HOME}/.claude"

if [[ -f "${DEST}" ]]; then
    backup_file "${DEST}"
fi

sed "s#__HOME__#${HOME}#g" "${SOURCE}" > "${DEST}"
log_info "Installed settings.json → ${DEST}"

record_result "${COMPONENT_ID}" "OK"
log_success "settings.json installed"
