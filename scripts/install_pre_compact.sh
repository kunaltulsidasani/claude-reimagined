#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

COMPONENT_ID="pre-compact"
COMPONENT_NAME="pre-compact hook"
COMPONENT_DESC="PreCompact hook that injects project-aware instructions into Claude's compaction summarizer, preserving mid-task state across context resets"
COMPONENT_CHANGES="Copies hooks/pre-compact.sh to ~/.claude/hooks/, registers it as a PreCompact hook in ~/.claude/settings.json"

if is_skipped "${COMPONENT_ID}"; then
    record_result "${COMPONENT_ID}" "SKIPPED" "skipped via flag"
    exit 0
fi

SOURCE="${SCRIPT_DIR}/../hooks/pre-compact.sh"
HOOK_DEST="${HOME}/.claude/hooks/pre-compact.sh"
SETTINGS_JSON="${HOME}/.claude/settings.json"

if [[ ! -f "${SOURCE}" ]]; then
    log_warn "hooks/pre-compact.sh not found in repo"
    record_result "${COMPONENT_ID}" "SKIPPED" "source file not found"
    exit 0
fi

if [[ -f "${HOOK_DEST}" ]] && grep -q "pre-compact" "${SETTINGS_JSON}" 2>/dev/null; then
    if ! is_force; then
        log_skip "pre-compact hook already installed"
        record_result "${COMPONENT_ID}" "SKIPPED" "already installed"
        exit 0
    fi
fi

if ! ask_confirm "${COMPONENT_ID}" "${COMPONENT_NAME}" "${COMPONENT_DESC}" "${COMPONENT_CHANGES}"; then
    record_result "${COMPONENT_ID}" "DECLINED" "user declined"
    exit 0
fi

if is_dry_run; then
    log_dry "Would copy ${SOURCE} → ${HOOK_DEST}"
    log_dry "Would register PreCompact hook in ${SETTINGS_JSON}"
    exit 0
fi

mkdir -p "${HOME}/.claude/hooks"
cp "${SOURCE}" "${HOOK_DEST}"
chmod +x "${HOOK_DEST}"
log_info "Copied pre-compact.sh → ${HOOK_DEST}"

mkdir -p "${HOME}/.claude"

if [[ -f "${SETTINGS_JSON}" ]]; then
    backup_file "${SETTINGS_JSON}"
fi

python3 - "${SETTINGS_JSON}" "${HOOK_DEST}" <<'PYEOF'
import sys, json, os

settings_file = sys.argv[1]
hook_path = sys.argv[2]

if os.path.exists(settings_file):
    with open(settings_file, "r") as f:
        data = json.load(f)
else:
    data = {}

hooks = data.setdefault("hooks", {})
pre_compact = hooks.setdefault("PreCompact", [])

hook_command = f'bash "{hook_path}"'

for entry in pre_compact:
    for h in entry.get("hooks", []):
        if hook_path in h.get("command", ""):
            print(f"[INFO]  Already registered in {settings_file}", file=sys.stderr)
            sys.exit(0)

pre_compact.append({
    "hooks": [
        {
            "type": "command",
            "command": hook_command
        }
    ]
})

with open(settings_file, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")

print(f"[INFO]  Registered pre-compact hook in {settings_file}", file=sys.stderr)
PYEOF

log_info "Registered PreCompact hook in ${SETTINGS_JSON}"
record_result "${COMPONENT_ID}" "OK"
log_success "pre-compact hook installed successfully"
