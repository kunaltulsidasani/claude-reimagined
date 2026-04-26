#!/usr/bin/env bash
# Integration tests for scripts/install_skills.sh
# Network download tests require: SKILLS_INTEGRATION_NETWORK=1
set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "${TESTS_DIR}/.." && pwd)"
source "${TESTS_DIR}/lib/helpers.sh"

SCRIPT="${REPO_ROOT}/scripts/install_skills.sh"
REGISTRY="${REPO_ROOT}/skills/registry.yaml"

if ! command -v git >/dev/null 2>&1; then
    skip "git not found — skipping skills integration tests"
    summary; exit 0
fi

if ! command -v python3 >/dev/null 2>&1; then
    skip "python3 not found — skipping skills integration tests"
    summary; exit 0
fi

setup_tmp

fake_home() { echo "${TMPDIR_TEST}/home_$$_${RANDOM}"; }

# ── Registry parse: at least one skill extracted ─────────────────────────────

suite "install_skills — registry parse"

parsed="$(python3 - "${REGISTRY}" <<'PYEOF'
import sys

registry_file = sys.argv[1]
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
    if s.get("id") and s.get("repo") and s.get("path") is not None:
        print(f"{s['id']}|{s['repo']}|{s['path']}")
PYEOF
)"

skill_count="$(printf '%s\n' "$parsed" | grep -c '|' || true)"
[[ "$skill_count" -gt 0 ]] && pass "registry parses ${skill_count} skills" \
                             || fail "registry parse produced no skills"

bad=0
while IFS='|' read -r sid repo spath; do
    [[ -z "$sid" || -z "$repo" || -z "$spath" ]] && bad=$(( bad + 1 ))
done <<< "$parsed"
[[ "$bad" -eq 0 ]] && pass "all registry entries have id|repo|path" \
                    || fail "${bad} registry entries missing fields"

# ── Dry-run: no files written ─────────────────────────────────────────────────

suite "install_skills — dry-run"

h=$(fake_home); mkdir -p "$h"
out="$(HOME="$h" BOOTSTRAP_DRY_RUN=1 BOOTSTRAP_YES=1 BOOTSTRAP_FORCE=0 \
       BOOTSTRAP_SKIP="" BOOTSTRAP_LOG_DIR="${h}/logs" \
       bash "$SCRIPT" 2>&1)"
rc=$?

assert_exit_ok "dry-run exits 0" "$rc"
assert_contains "dry-run prints Would create" "Would create" "$out"
assert_file_not_exists "dry-run: skills dir not created" "${h}/.claude/skills"

# ── Network: download all skills, call out failures, cleanup via trap ─────────

suite "install_skills — network download (all skills)"

if [[ "${SKILLS_INTEGRATION_NETWORK:-0}" != "1" ]]; then
    skip "network tests skipped (set SKILLS_INTEGRATION_NETWORK=1 to enable)"
else
    h=$(fake_home); mkdir -p "$h"

    # Run installer — allow non-zero exit (partial failures reported per-skill)
    HOME="$h" BOOTSTRAP_DRY_RUN=0 BOOTSTRAP_YES=1 BOOTSTRAP_FORCE=0 \
      BOOTSTRAP_SKIP="" BOOTSTRAP_LOG_DIR="${h}/logs" \
      bash "$SCRIPT" 2>&1 || true

    results_tsv="${h}/logs/results.tsv"

    if [[ ! -f "$results_tsv" ]]; then
        fail "results.tsv not written — installer did not run"
    else
        ok_skills=0
        fail_skills=0
        fail_names=()

        while IFS=$'\t' read -r _ts component status _detail; do
            # Only process skills:* entries
            [[ "$component" == skills:* ]] || continue
            sid="${component#skills:}"
            if [[ "$status" == "OK" || "$status" == "SKIPPED" ]]; then
                ok_skills=$(( ok_skills + 1 ))
            else
                fail_skills=$(( fail_skills + 1 ))
                fail_names+=("$sid")
            fi
        done < "$results_tsv"

        # One assert per skill: pass if OK/SKIPPED, fail with name if not
        for sid in "${fail_names[@]}"; do
            fail "skill failed: ${sid}"
        done

        total_skills=$(( ok_skills + fail_skills ))
        if [[ "$fail_skills" -eq 0 ]]; then
            pass "all ${total_skills} skills installed successfully"
        else
            # Individual failures already reported above; summary pass for ok count
            [[ "$ok_skills" -gt 0 ]] && pass "${ok_skills}/${total_skills} skills installed"
        fi

        # Verify SKILL.md present for each installed skill dir
        skill_dirs=( "${h}/.claude/skills"/*/  )
        if [[ "${#skill_dirs[@]}" -gt 0 && -d "${skill_dirs[0]}" ]]; then
            missing_skill_md=0
            for d in "${skill_dirs[@]}"; do
                [[ -f "${d}/SKILL.md" ]] || missing_skill_md=$(( missing_skill_md + 1 ))
            done
            [[ "$missing_skill_md" -eq 0 ]] \
                && pass "all installed skill dirs contain SKILL.md" \
                || fail "${missing_skill_md} skill dirs missing SKILL.md"
        fi
    fi

    # Cleanup downloaded skills (TMPDIR_TEST trap handles the rest)
    rm -rf "${h}/.claude/skills"
fi

summary
