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
# Write keys/values to temp files (newline-separated) — portable on macOS + Linux
_keys_tmp="$(mktemp)"
_vals_tmp="$(mktemp)"
printf '%s\n' "${safe_keys[@]+"${safe_keys[@]}"}"   > "${_keys_tmp}"
printf '%s\n' "${safe_values[@]+"${safe_values[@]}"}" > "${_vals_tmp}"

python3 - "${settings_json}" "${_keys_tmp}" "${_vals_tmp}" <<'PYEOF'
import sys, json, os

settings_file = sys.argv[1]
keys_file = sys.argv[2]
vals_file = sys.argv[3]

with open(keys_file) as f:
    keys = [l.rstrip("\n") for l in f if l.strip()]
with open(vals_file) as f:
    values = [l.rstrip("\n") for l in f if l.strip()]

pairs = dict(zip(keys, values))

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
rm -f "${_keys_tmp}" "${_vals_tmp}"

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
