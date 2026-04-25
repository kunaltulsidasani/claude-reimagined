#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

COMPONENT_ID="subagent-router"
COMPONENT_NAME="subagent-model-router"
COMPONENT_DESC="PreToolUse hook that routes Agent tool calls to the optimal model (haiku/sonnet) based on subagent type and prompt complexity"
COMPONENT_CHANGES="Copies hooks/subagent-model-router.sh to ~/.claude/hooks/, registers it as a PreToolUse hook in ~/.claude/settings.json"

if is_skipped "${COMPONENT_ID}"; then
    record_result "${COMPONENT_ID}" "SKIPPED" "skipped via flag"
    exit 0
fi

SOURCE="${SCRIPT_DIR}/../hooks/subagent-model-router.sh"
HOOK_DEST="${HOME}/.claude/hooks/subagent-model-router.sh"
SETTINGS_JSON="${HOME}/.claude/settings.json"

if [[ ! -f "${SOURCE}" ]]; then
    log_warn "hooks/subagent-model-router.sh not found in repo"
    record_result "${COMPONENT_ID}" "SKIPPED" "source file not found"
    exit 0
fi

if [[ -f "${HOOK_DEST}" ]] && grep -q "subagent-model-router" "${SETTINGS_JSON}" 2>/dev/null; then
    if ! is_force; then
        log_skip "subagent-model-router already installed"
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
    log_dry "Would register PreToolUse[Agent] hook in ${SETTINGS_JSON}"
    exit 0
fi

mkdir -p "${HOME}/.claude/hooks"
cp "${SOURCE}" "${HOOK_DEST}"
chmod +x "${HOOK_DEST}"
log_info "Copied subagent-model-router.sh → ${HOOK_DEST}"

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
pre_tool_use = hooks.setdefault("PreToolUse", [])

hook_command = f'bash "{hook_path}"'

# Check if Agent matcher already registered
for entry in pre_tool_use:
    if entry.get("matcher") == "Agent":
        for h in entry.get("hooks", []):
            if hook_path in h.get("command", ""):
                print(f"[INFO]  Already registered in {settings_file}", file=sys.stderr)
                sys.exit(0)
        # Matcher exists but hook not present — append
        entry.setdefault("hooks", []).append({
            "type": "command",
            "command": hook_command,
            "timeout": 5,
            "async": True
        })
        break
else:
    # No Agent matcher — create one
    pre_tool_use.append({
        "matcher": "Agent",
        "hooks": [
            {
                "type": "command",
                "command": hook_command,
                "timeout": 5,
                "async": True
            }
        ]
    })

with open(settings_file, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")

print(f"[INFO]  Registered subagent-model-router in {settings_file}", file=sys.stderr)
PYEOF

log_info "Registered PreToolUse[Agent] hook in ${SETTINGS_JSON}"
record_result "${COMPONENT_ID}" "OK"
log_success "subagent-model-router installed successfully"
