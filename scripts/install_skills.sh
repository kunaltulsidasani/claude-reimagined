#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

COMPONENT_ID="skills"
COMPONENT_NAME="Claude Code Skills"
COMPONENT_DESC="Installs 40 curated skills (languages, databases, infra, testing, API, engineering, process) into ~/.claude/skills/"
COMPONENT_CHANGES="Creates/populates ~/.claude/skills/<skill-id>/ directories by sparse-cloning source GitHub repos"

REGISTRY="${SCRIPT_DIR}/../skills/registry.yaml"
SKILLS_DEST="${HOME}/.claude/skills"

# ── Optional filter: SKILLS_ONLY="python-pro,golang-pro" to install a subset ──
SKILLS_ONLY="${SKILLS_ONLY:-}"

if is_skipped "${COMPONENT_ID}"; then
    record_result "${COMPONENT_ID}" "SKIPPED" "skipped via flag"
    exit 0
fi

if [[ ! -f "${REGISTRY}" ]]; then
    log_error "Registry not found: ${REGISTRY}"
    record_result "${COMPONENT_ID}" "FAILED" "registry missing"
    exit 1
fi

require_command git   "Install git: https://git-scm.com"
require_command python3 "Install Python 3"

if ! ask_confirm "${COMPONENT_ID}" "${COMPONENT_NAME}" "${COMPONENT_DESC}" "${COMPONENT_CHANGES}"; then
    record_result "${COMPONENT_ID}" "DECLINED" "user declined"
    exit 0
fi

if is_dry_run; then
    log_dry "Would create: ${SKILLS_DEST}/"
    log_dry "Would sparse-clone repos listed in ${REGISTRY}"
    log_dry "Would copy each skill path → ${SKILLS_DEST}/<skill-id>/"
    exit 0
fi

mkdir -p "${SKILLS_DEST}"

# ── Parse registry into a TSV: skill_id|repo|path ──────────────────────────
PARSED_TSV="$(python3 - "${REGISTRY}" "${SKILLS_ONLY}" <<'PYEOF'
import sys, re

registry_file = sys.argv[1]
only_filter = set(x.strip() for x in sys.argv[2].split(",") if x.strip()) if len(sys.argv) > 2 else set()

with open(registry_file) as f:
    content = f.read()

skills = []
current = {}
for line in content.splitlines():
    stripped = line.strip()
    if stripped.startswith("- id:"):
        if current.get("id"):
            skills.append(current)
        current = {"id": stripped.split(":", 1)[1].strip()}
    elif stripped.startswith("repo:"):
        current["repo"] = stripped.split(":", 1)[1].strip()
    elif stripped.startswith("path:"):
        current["path"] = stripped.split(":", 1)[1].strip()
if current.get("id"):
    skills.append(current)

for s in skills:
    if only_filter and s["id"] not in only_filter:
        continue
    if s.get("id") and s.get("repo") and s.get("path") is not None:
        print(f"{s['id']}|{s['repo']}|{s['path']}")
PYEOF
)"

# ── Group by repo ────────────────────────────────────────────────────────────
declare -A REPO_SKILLS   # repo → "skill_id:path skill_id:path ..."

while IFS='|' read -r skill_id repo path; do
    [[ -z "${skill_id}" ]] && continue
    entry="${skill_id}:${path}"
    REPO_SKILLS["${repo}"]="${REPO_SKILLS[${repo}]:-} ${entry}"
done <<< "${PARSED_TSV}"

TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "${TMPDIR_BASE}"' EXIT

ok_count=0
fail_count=0
skip_count=0

# ── Process each repo ────────────────────────────────────────────────────────
for repo in "${!REPO_SKILLS[@]}"; do
    log_info "Processing repo: ${repo}"

    repo_tmpdir="${TMPDIR_BASE}/$(echo "${repo}" | tr '/' '_')"
    mkdir -p "${repo_tmpdir}"

    # Collect sparse paths for this repo
    sparse_paths=()
    needs_full_repo=false
    declare -A skill_path_map   # skill_id → path_in_repo
    read -ra _entries <<< "${REPO_SKILLS[${repo}]:-}"
    for entry in "${_entries[@]}"; do
        [[ -z "${entry}" ]] && continue
        s_id="${entry%%:*}"
        s_path="${entry#*:}"
        skill_path_map["${s_id}"]="${s_path}"
        if [[ "${s_path}" == "." ]]; then
            # Root-path skill — sparse-checkout cone-mode default excludes subdirs,
            # so we must disable sparse to get scripts/, reference/, etc.
            needs_full_repo=true
        else
            sparse_paths+=("${s_path}")
        fi
    done

    # Sparse clone — only fetch needed directories
    clone_url="https://github.com/${repo}.git"
    if ! git clone \
            --depth 1 \
            --filter=blob:none \
            --sparse \
            --quiet \
            "${clone_url}" \
            "${repo_tmpdir}" 2>/dev/null; then
        log_warn "Failed to clone ${repo} — skipping all its skills"
        for s_id in "${!skill_path_map[@]}"; do
            record_result "${COMPONENT_ID}:${s_id}" "FAILED" "clone failed"
            fail_count=$(( fail_count + 1 ))
        done
        unset skill_path_map
        continue
    fi

    # Set sparse-checkout paths (or disable for root-path skills)
    if [[ "${needs_full_repo}" == true ]]; then
        (
            cd "${repo_tmpdir}"
            git sparse-checkout disable 2>/dev/null || true
        )
    elif [[ ${#sparse_paths[@]} -gt 0 ]]; then
        (
            cd "${repo_tmpdir}"
            git sparse-checkout set --no-cone "${sparse_paths[@]}" 2>/dev/null || true
        )
    fi

    # Copy each skill to dest
    for s_id in "${!skill_path_map[@]}"; do
        s_path="${skill_path_map[${s_id}]}"
        dest="${SKILLS_DEST}/${s_id}"

        if [[ "${s_path}" == "." ]]; then
            src_dir="${repo_tmpdir}"
        else
            src_dir="${repo_tmpdir}/${s_path}"
        fi

        if [[ ! -d "${src_dir}" ]] && [[ ! -f "${src_dir}/SKILL.md" ]] && [[ ! -f "${repo_tmpdir}/SKILL.md" ]]; then
            # Try root-level SKILL.md fallback
            if [[ -f "${repo_tmpdir}/SKILL.md" ]]; then
                src_dir="${repo_tmpdir}"
            else
                log_warn "Path not found in ${repo}: ${s_path} (skill: ${s_id})"
                record_result "${COMPONENT_ID}:${s_id}" "FAILED" "path not found: ${s_path}"
                fail_count=$(( fail_count + 1 ))
                continue
            fi
        fi

        if [[ -d "${dest}" ]] && ! is_force; then
            log_skip "Already installed: ${s_id}"
            record_result "${COMPONENT_ID}:${s_id}" "SKIPPED" "already exists"
            skip_count=$(( skip_count + 1 ))
            continue
        fi

        rm -rf "${dest}"
        cp -r "${src_dir}" "${dest}"
        log_success "Installed: ${s_id} → ${dest}"
        record_result "${COMPONENT_ID}:${s_id}" "OK" "from ${repo}:${s_path}"
        ok_count=$(( ok_count + 1 ))
    done

    unset skill_path_map
done

# ── Summary ──────────────────────────────────────────────────────────────────
printf "\n${_BOLD}Skills install summary:${_RESET}\n"
printf "  Installed: %d\n" "${ok_count}"
printf "  Skipped:   %d\n" "${skip_count}"
printf "  Failed:    %d\n" "${fail_count}"

if [[ "${fail_count}" -gt 0 ]]; then
    log_warn "${fail_count} skill(s) failed — check paths in skills/registry.yaml"
    record_result "${COMPONENT_ID}" "PARTIAL" "ok=${ok_count} skip=${skip_count} fail=${fail_count}"
else
    record_result "${COMPONENT_ID}" "OK" "ok=${ok_count} skip=${skip_count}"
    log_success "Skills installed to ${SKILLS_DEST}"
fi
