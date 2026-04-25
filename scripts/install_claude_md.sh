#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=../lib/common.sh
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

COMPONENT_ID="claude-md"
name="Claude MD Config Files"
description="Install ~/.claude/CLAUDE.md and ~/.claude/RTK.md from repo reference copies"
changes="~/.claude/CLAUDE.md (merge if exists), ~/.claude/RTK.md (overwrite)"

SRC_CLAUDE_MD="${SCRIPT_DIR}/../configs/CLAUDE.md"
SRC_RTK_MD="${SCRIPT_DIR}/../configs/RTK.md"

DEST_CLAUDE_MD="${HOME}/.claude/CLAUDE.md"
DEST_RTK_MD="${HOME}/.claude/RTK.md"

if is_skipped "${COMPONENT_ID}"; then
    record_result "${COMPONENT_ID}" "SKIPPED" "via --skip"
    exit 0
fi

# Skip if both destinations exist and not --force
if [[ -f "${DEST_CLAUDE_MD}" && -f "${DEST_RTK_MD}" ]]; then
    if ! is_force; then
        log_skip "Both ~/.claude/CLAUDE.md and ~/.claude/RTK.md already exist (use --force to overwrite)"
        record_result "${COMPONENT_ID}" "SKIPPED" "already installed"
        exit 0
    fi
fi

if ! ask_confirm "${COMPONENT_ID}" "${name}" "${description}" "${changes}"; then
    record_result "${COMPONENT_ID}" "DECLINED"
    exit 0
fi

if is_dry_run; then
    log_dry "Would create: ${HOME}/.claude/ (if missing)"
    if [[ -f "${DEST_CLAUDE_MD}" ]]; then
        log_dry "Would merge (append missing lines): ${DEST_CLAUDE_MD} from ${SRC_CLAUDE_MD}"
    else
        log_dry "Would copy: ${SRC_CLAUDE_MD} -> ${DEST_CLAUDE_MD}"
    fi
    log_dry "Would backup and overwrite: ${DEST_RTK_MD} from ${SRC_RTK_MD}"
    exit 0
fi

# Ensure ~/.claude/ exists
mkdir -p "${HOME}/.claude"

# --- CLAUDE.md: merge if exists, copy if not ---
if [[ -f "${DEST_CLAUDE_MD}" ]]; then
    backup_file "${DEST_CLAUDE_MD}"
    log_info "Merging missing lines from ${SRC_CLAUDE_MD} into ${DEST_CLAUDE_MD}"
    python3 - "${SRC_CLAUDE_MD}" "${DEST_CLAUDE_MD}" <<'PYEOF'
import sys

src_path = sys.argv[1]
dest_path = sys.argv[2]

with open(src_path, "r") as f:
    src_lines = f.readlines()

with open(dest_path, "r") as f:
    dest_content = f.read()
    dest_lines = dest_content.splitlines(keepends=True)

dest_lines_stripped = set(line.rstrip("\n") for line in dest_lines)

lines_to_append = [
    line for line in src_lines
    if line.rstrip("\n") not in dest_lines_stripped
]

if lines_to_append:
    with open(dest_path, "a") as f:
        if dest_content and not dest_content.endswith("\n"):
            f.write("\n")
        f.writelines(lines_to_append)
    print(f"Appended {len(lines_to_append)} line(s) to {dest_path}")
else:
    print(f"No new lines to append to {dest_path}")
PYEOF
else
    log_info "Copying ${SRC_CLAUDE_MD} -> ${DEST_CLAUDE_MD}"
    cp "${SRC_CLAUDE_MD}" "${DEST_CLAUDE_MD}"
fi

# --- RTK.md: backup and overwrite ---
if [[ -f "${DEST_RTK_MD}" ]]; then
    backup_file "${DEST_RTK_MD}"
fi
log_info "Copying ${SRC_RTK_MD} -> ${DEST_RTK_MD}"
cp "${SRC_RTK_MD}" "${DEST_RTK_MD}"

log_success "CLAUDE.md and RTK.md installed successfully"
record_result "${COMPONENT_ID}" "OK"
