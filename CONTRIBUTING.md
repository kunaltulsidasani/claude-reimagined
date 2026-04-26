# Contributing to claude-reimagined

Thanks for your interest. This guide covers development setup, conventions, and how to add new components or skills.

## Table of Contents

- [Development Setup](#development-setup)
- [Project Layout](#project-layout)
- [Running Tests](#running-tests)
- [Adding a New Component](#adding-a-new-component)
- [Adding a New Skill](#adding-a-new-skill)
- [Coding Conventions](#coding-conventions)
- [Commit Style](#commit-style)
- [Pull Requests](#pull-requests)

## Development Setup

Clone and install in dev mode:

```bash
git clone https://github.com/kunaltulsidasani/claude-reimagined.git
cd claude-reimagined
./bootstrap.sh --dry-run     # verify scripts work without modifying anything
make test                    # run the full test suite
```

You don't need to install the suite to develop — `--dry-run` exercises every script's logic without touching `~/.claude/`.

## Project Layout

```
bootstrap.sh           # entry point — calls scripts/install_*.sh in order
configs/settings.json  # reference Claude Code settings
hooks/                 # PreCompact and PreToolUse[Agent] hook scripts
lib/common.sh          # shared bash helpers — log_*, ask_confirm, record_result, is_force, etc.
scripts/install_*.sh   # one script per component
skills/registry.yaml   # canonical skill list
tests/                 # bash test suite (zero deps)
```

Every install script follows the same structure — read `scripts/install_statusline.sh` as a minimal reference.

## Running Tests

The test runner is plain bash, no frameworks.

```bash
make test                                    # full suite
bash tests/run_tests.sh                      # same, direct
bash tests/integration/test_install_skills.sh # one suite
```

- **Unit tests** (`tests/unit/`) — exercise `lib/common.sh`, hook routing logic, and individual functions.
- **Integration tests** (`tests/integration/`) — drive each `scripts/install_*.sh` end-to-end against a tmp `$HOME` so they never touch your real `~/.claude`.

Tests use helpers from `tests/lib/helpers.sh` — `assert_eq`, `assert_contains`, `setup_fake_home`, etc.

A new install script must ship with a matching `tests/integration/test_install_<id>.sh`. A test is one bash function per scenario; the runner discovers them automatically.

## Adding a New Component

1. **Create the install script** — `scripts/install_<id>.sh`. Source `lib/common.sh` at the top. Implement: skip-check → confirm prompt → dry-run branch → actual install → record_result.
2. **Wire it into `bootstrap.sh`** — add a line in the install order. Decide if it's critical (abort on failure) or non-critical (warn and continue).
3. **Document it** — add a row in the [What You Get](README.md#what-you-get) table with the upstream link and one-sentence pitch.
4. **Add an integration test** — `tests/integration/test_install_<id>.sh`. Cover at minimum: dry-run, --skip, idempotent re-run, and failure path.
5. **Verify** — `bash tests/integration/test_install_<id>.sh && make test`.

Use `lib/common.sh` for everything: logging (`log_info`, `log_error`, `log_success`), prompts (`ask_confirm`), state (`is_force`, `is_skipped`, `is_dry_run`), result recording (`record_result <id> <STATUS> <message>`). Don't reinvent these.

## Adding a New Skill

Edit `skills/registry.yaml`. Add an entry under the appropriate category:

```yaml
- id: my-skill                    # install target → ~/.claude/skills/my-skill/
  category: engineering           # languages | databases | infrastructure | testing | api | engineering | tooling
  repo: owner/repo                # GitHub source
  path: skills/my-skill           # path inside the repo containing SKILL.md
  tier: gold                      # gold | silver | bronze (see below)
  description: One-line pitch
```

### Tier definitions

| Tier | Required | When to use |
|------|----------|-------------|
| **gold** | `SKILL.md` + `scripts/` + `reference/` directories | Skills with executable helpers (review, debug, infra, test). Verify both subdirs exist via `gh api repos/<owner>/<repo>/contents/<path>` before tagging gold. |
| **silver** | `SKILL.md` + helper scripts or refs inline | Skills that ship code/refs alongside SKILL.md but without dedicated subdirectories. |
| **bronze** | `SKILL.md` only | Knowledge-only skills (language idioms, design philosophy) where scripts add no value. |

### Verifying a candidate

```bash
gh api repos/<owner>/<repo>/git/trees/HEAD?recursive=1 \
  --jq '.tree[] | select(.path | startswith("<path>/")) | .path'
```

If `<path>/scripts/...` and `<path>/reference/...` (or `<path>/references/...`) appear in the listing, it's gold. Inline helpers without subdirs is silver.

### Testing the install

```bash
make install SKILLS_ONLY=my-skill BOOTSTRAP_FORCE=1 BOOTSTRAP_YES=1
ls ~/.claude/skills/my-skill/
```

Confirm the expected subdirectories made it through. Root-path skills (`path: .`) trigger `git sparse-checkout disable` to fetch the full repo — sparse-checkout cone-mode would otherwise strip subdirs.

## Coding Conventions

### Bash

- `set -euo pipefail` at the top of every script.
- `# shellcheck source=...` directives so shellcheck stays happy.
- Quote every variable expansion (`"${var}"`, not `$var`).
- Source `lib/common.sh` for shared helpers — don't duplicate logging, prompts, or result recording.
- Local variables in functions: `local var=...`.
- Filenames are snake_case.sh; functions are snake_case.

### Hooks

Hooks read JSON from stdin and write JSON to stdout. Use `jq` to manipulate. See `hooks/subagent-model-router.sh` for the pattern.

### Settings

`configs/settings.json` is a reference, not auto-installed. If you add a setting, document it in the [Settings](README.md#settings) table with the rationale.

## Commit Style

Conventional Commits — keep the subject under 70 characters.

```
fix(skills): preserve subdirs for root-path skills

Body explains *why*, not what. Reference issues and prior art.
```

Common types: `feat`, `fix`, `chore`, `refactor`, `test`, `docs`.

## Pull Requests

- Run `make test` before opening — the suite is fast, no excuse to skip it.
- Include a "Why" paragraph in the description — what pain point does this fix?
- Update the README and CONTRIBUTING when behavior changes.
- One concern per PR. Refactors and feature work go in separate PRs.

Issue and PR templates live in `.github/` (forthcoming). Until then, free-form is fine.
