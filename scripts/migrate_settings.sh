#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

COMPONENT_ID="settings"
COMPONENT_NAME="settings migration"
COMPONENT_DESC="Migrates existing Claude Code settings from settings.sh or other locations into ~/.claude/settings.json"
COMPONENT_CHANGES="Reads settings.sh, copies safe KEY=VALUE pairs into ~/.claude/settings.json (with backup)"

if is_skipped "${COMPONENT_ID}"; then
    record_result "${COMPONENT_ID}" "SKIPPED" "skipped via flag"
    exit 0
fi

SEARCH_PATHS=(
    "${HOME}/.claude/settings.sh"
    "${HOME}/.config/claude/settings.sh"
    "./settings.sh"
    "${SCRIPT_DIR}/../settings.sh"
)

source_path=""
for candidate in "${SEARCH_PATHS[@]}"; do
    if [[ -f "${candidate}" ]]; then
        source_path="$(cd "$(dirname "${candidate}")" && pwd)/$(basename "${candidate}")"
        break
    fi
done

if [[ -z "${source_path}" ]]; then
    log_info "No settings.sh found — skipping migration"
    record_result "${COMPONENT_ID}" "SKIPPED" "no source found"
    exit 0
fi

log_info "Found settings.sh at: ${source_path}"

if ! ask_confirm "${COMPONENT_ID}" "${COMPONENT_NAME}" "${COMPONENT_DESC}" "${COMPONENT_CHANGES}"; then
    record_result "${COMPONENT_ID}" "DECLINED" "user declined"
    exit 0
fi

# Parse settings.sh safely — never source/eval it.
# Extract only simple KEY=VALUE lines; skip comments, blanks, and shell constructs.
declare -a safe_keys=()
declare -a safe_values=()
declare -a skipped_keys=()

while IFS= read -r line; do
    # Skip blank lines and comments
    [[ -z "${line}" || "${line}" =~ ^[[:space:]]*# ]] && continue

    # Must match a plain VAR= assignment
    if [[ ! "${line}" =~ ^[A-Z_][A-Z0-9_]*= ]]; then
        continue
    fi

    # Skip lines with shell constructs that are unsafe to parse statically
    if [[ "${line}" =~ \$\( || "${line}" =~ \` || "${line}" =~ \; ]]; then
        key="${line%%=*}"
        skipped_keys+=("${key}")
        log_warn "Skipping complex assignment (not migrated): ${key}"
        continue
    fi

    key="${line%%=*}"
    # Strip leading/trailing quotes from value
    raw_value="${line#*=}"
    value="${raw_value#\"}"
    value="${value%\"}"
    value="${value#\'}"
    value="${value%\'}"

    log_info "Extracted key: ${key}"
    safe_keys+=("${key}")
    safe_values+=("${value}")
done < "${source_path}"

if [[ "${#safe_keys[@]}" -eq 0 ]]; then
    log_info "No safe KEY=VALUE pairs found to migrate"
    record_result "${COMPONENT_ID}" "SKIPPED" "no migratable keys found"
    exit 0
fi

settings_json="${HOME}/.claude/settings.json"
mkdir -p "${HOME}/.claude"

if is_dry_run; then
    log_dry "Would migrate the following keys into ${settings_json}:"
    for key in "${safe_keys[@]}"; do
        log_dry "  ${key}"
    done
    exit 0
fi

if [[ -f "${settings_json}" ]]; then
    backup_file "${settings_json}"
fi

# Build a JSON fragment from extracted keys/values and merge into settings.json
# Pass keys/values via a temp JSON file to avoid whitespace-splitting on [*]
_kv_tmp="$(mktemp)"
python3 -c "import sys, json; print(json.dumps(dict(zip(sys.argv[1].split('\x00'), sys.argv[2].split('\x00')))))" \
    "$(printf '%s\0' "${safe_keys[@]}" | head -c -1)" \
    "$(printf '%s\0' "${safe_values[@]}" | head -c -1)" > "${_kv_tmp}"

python3 - "${settings_json}" "${_kv_tmp}" <<'PYEOF'
import sys, json, os

settings_file = sys.argv[1]
kv_file = sys.argv[2]

with open(kv_file) as f:
    pairs = json.load(f)

if os.path.exists(settings_file):
    with open(settings_file) as f:
        data = json.load(f)
else:
    data = {}

data.update(pairs)

with open(settings_file, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PYEOF
rm -f "${_kv_tmp}"

log_info "Merged ${#safe_keys[@]} key(s) into ${settings_json}"

# Preserve original for reference
migrated_copy="${source_path}.migrated"
cp "${source_path}" "${migrated_copy}"
log_info "Original settings.sh preserved at: ${migrated_copy}"

if [[ "${#skipped_keys[@]}" -gt 0 ]]; then
    log_warn "The following keys contain complex shell logic and were NOT migrated automatically:"
    for key in "${skipped_keys[@]}"; do
        log_warn "  ${key}"
    done
    log_warn "Review ${source_path} and add them manually to ${settings_json} if needed."
fi

record_result "${COMPONENT_ID}" "OK"
log_success "Settings migration complete"
