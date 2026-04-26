# claude-reimagined

Bootstrap system for Claude Code and its plugin ecosystem. Single command installs and wires together Claude Code, RTK, context-mode, code-review-graph, caveman, statusline, subagent router, pre-compact hook, CLAUDE.md, and a curated skill library on macOS and Linux.

## Quick Start

```bash
./bootstrap.sh                                        # interactive install
./bootstrap.sh --dry-run                              # preview without installing
./bootstrap.sh --force                                # reinstall everything
./bootstrap.sh --yes                                  # non-interactive, auto-approve all
./bootstrap.sh --clean --yes                          # wipe ~/.claude, then install fresh
./bootstrap.sh --skip rtk                             # skip a component
./bootstrap.sh --skip rtk,caveman --yes               # skip multiple, non-interactive
./bootstrap.sh --skills-only python-pro,golang-pro    # install only specific skills
```

## Components

| Component | What it installs | Why | Skip flag | Verify |
|-----------|-----------------|-----|-----------|--------|
| deps | curl, git, python3, node/npm, jq, pipx | hard dependencies for all other components | `--skip deps` | all present in PATH |
| claude-code | Claude Code CLI | the AI coding assistant this whole system is built on | `--skip claude-code` | `claude --version` |
| settings | `configs/settings.json` → `~/.claude/settings.json` | applies UX prefs, hooks, statusline, env vars in one shot | `--skip settings-config` | `~/.claude/settings.json` |
| rtk | token-saving shell proxy | rewrites Bash commands through RTK, cuts context usage 60–90% on shell output | `--skip rtk` | `rtk gain` |
| code-review-graph | persistent codebase knowledge graph | lets Claude review code with structural context instead of re-reading files every turn | `--skip code-review-graph` | `code-review-graph --version` |
| context-mode | MCP plugin (sandboxed command output) | large command output goes to a sandbox; Claude searches it instead of flooding context | `--skip context-mode` | `claude mcp list` |
| caveman | Claude Code plugin | installs caveman communication mode — terse, token-efficient Claude responses | `--skip caveman` | `~/.claude/settings.json` |
| statusline | shell statusline script | shows Claude Code session state (model, tokens, cost) in the terminal statusline | `--skip statusline` | `~/.claude/statusline.sh` |
| subagent-router | `PreToolUse` hook on `Agent` calls | routes subagents to cheapest capable model automatically; saves cost on every spawned agent | `--skip subagent-router` | `~/.claude/hooks/subagent-model-router.sh` |
| pre-compact | `PreCompact` hook | injects project-aware instructions into Claude's compaction summarizer so mid-task state survives context resets | `--skip pre-compact` | `~/.claude/hooks/pre-compact.sh` |
| claude-md | global `CLAUDE.md` | installs skill router instructions and project conventions Claude reads at session start | `--skip claude-md` | `~/.claude/CLAUDE.md` |
| settings (migrate) | reads legacy `settings.sh` | carries forward any existing Claude settings rather than clobbering them | `--skip settings` | no-op if no `settings.sh` found |
| skills | 40+ skill dirs in `~/.claude/skills/` | domain-specific prompting libraries Claude picks up automatically via the skill router | `--skip skills` | `~/.claude/skills/` |


## Hooks

### `pre-compact` — PreCompact hook

**File:** `hooks/pre-compact.sh` → `~/.claude/hooks/pre-compact.sh`

**When it fires:** immediately before Claude auto-compacts the context window (triggered at 80% by `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`).

**What it does:** detects the project's tech stack, schema files, API directories, and git state, then writes custom instructions to stdout. Claude's compaction summarizer reads these instructions and uses them to decide what to preserve.

**Why:** Claude's default compaction drops too much mid-task state. Without this hook, resuming after a compact means re-reading files and re-discovering errors. With it, the summary is guaranteed to contain: the active task and next step, exact error messages, every file touched, non-obvious decisions and their reasons, pending/blocked work, and discovered env constraints.

**Stack detection:** automatically identifies JS/TS (Next.js, NestJS, React, Node), Go, Python (FastAPI, Django, Flask), Rust, Flutter, Java/Maven, Kotlin/Gradle, Ruby/Rails, Swift, C#/.NET. Adjusts preservation instructions per stack (test command, build command, schema file, API dirs).

### `subagent-model-router` — PreToolUse hook on Agent

**File:** `hooks/subagent-model-router.sh` → `~/.claude/hooks/subagent-model-router.sh`

**When it fires:** before every `Agent` tool call.

**What it does:** inspects the `subagent_type` and prompt complexity, then rewrites the tool input to pin a specific model via `updatedInput`.

**Why:** spawning a Sonnet or Opus subagent for a pure file search is wasteful. This hook routes cheap work to Haiku automatically with no manual effort.

| Subagent type | Routed model |
|---------------|-------------|
| `Explore`, `statusline-setup`, `claude-code-guide` | Haiku |
| `general-purpose` with simple lookup prompt | Haiku |
| `general-purpose` with complex prompt (implement/debug/design/…) | Sonnet |
| `Plan`, `superpowers:code-reviewer` | Sonnet (floor) |
| everything else | inherits parent model |

## Settings Applied (`configs/settings.json`)

The `settings` component copies `configs/settings.json` → `~/.claude/settings.json`, substituting `__HOME__` with the actual home path.

| Setting | Value | Why |
|---------|-------|-----|
| `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` | `80` | triggers auto-compact at 80% context instead of default (95%), giving the pre-compact hook time to run before things get critical |
| `skillListingMaxDescChars` | `300` | caps skill descriptions in the listing to 300 chars — keeps the skill router prompt lean |
| `skillListingBudgetFraction` | `0.005` | limits skill listing to 0.5% of context budget — avoids the registry consuming meaningful tokens |
| `spinnerTipsEnabled` | `false` | disables loading tips — noise |
| `effortLevel` | `medium` | default thinking effort; override per-task with `/effort` |
| `promptSuggestionEnabled` | `false` | disables inline prompt suggestions — they interrupt flow |
| `tui` | `fullscreen` | uses the full-screen TUI instead of the inline terminal mode |
| `prefersReducedMotion` | `true` | disables animations in the TUI |
| `showThinkingSummaries` | `false` | hides extended thinking summaries from output — reduces noise |
| `autoScrollEnabled` | `false` | disables auto-scroll so output stays readable mid-task |

Hooks registered in settings.json:
- `PreCompact` → `pre-compact.sh` (project-aware compaction instructions)
- `PreToolUse[Agent]` → `subagent-model-router.sh` (model routing)

## Skills Library

40+ curated skills installed from community repos via sparse clone. Use `--skills-only <ids>` to install a subset.

| Skill | Category | Description |
|-------|----------|-------------|
| `python-pro` | Language | Python 3.11+ best practices |
| `typescript-pro` | Language | Advanced TypeScript type systems |
| `golang-pro` | Language | Go applications |
| `rust-pro` | Language | Rust systems programming |
| `java-architect` | Language | Java architecture patterns |
| `kotlin-specialist` | Language | Kotlin development |
| `swift-expert` | Language | Swift / iOS development |
| `csharp-developer` | Language | C# / .NET development |
| `cpp-pro` | Language | C++ systems programming |
| `php-pro` | Language | PHP development |
| `ruby-rails` | Language | Ruby on Rails |
| `elixir-pro` | Language | Elixir / Phoenix |
| `react` | Frontend | React patterns and hooks |
| `vue-expert` | Frontend | Vue 3 / Composition API |
| `angular-architect` | Frontend | Angular architecture |
| `nextjs-developer` | Frontend | Next.js full-stack |
| `flutter-expert` | Frontend | Flutter / Dart mobile |
| `nestjs-expert` | Backend | NestJS applications |
| `django-expert` | Backend | Django / Python web |
| `fastapi-expert` | Backend | FastAPI / async Python |
| `laravel-specialist` | Backend | Laravel / PHP web |
| `postgres-pro` | Database | PostgreSQL query optimization |
| `redis-pro` | Database | Redis client code |
| `dynamodb-pro` | Database | DynamoDB table design |
| `mongodb-pro` | Database | MongoDB patterns |
| `database-designer` | Database | Schema and ERD design |
| `aws-solution-architect` | Cloud | AWS architecture |
| `terraform` | Cloud | Infrastructure as code |
| `kubernetes-ops` | Cloud | Kubernetes operations |
| `docker` | Cloud | Docker / containerization |
| `ci-cd` | Cloud | CI/CD pipeline setup |
| `unit-tests` | Testing | Unit test patterns |
| `test-automation` | Testing | E2E and automation testing |
| `api-designer` | API | REST API design |
| `openapi-docs` | API | OpenAPI / Swagger docs |
| `api-security` | API | API security patterns |
| `system-design` | Architecture | System design |
| `tdd` | Practices | Test-driven development |
| `bdd` | Practices | Behavior-driven development |
| `code-reviewer` | Practices | Code review automation |
| `security-review` | Practices | Security review of changes |
| `debugging` | Practices | Debugging strategies |
| `git-workflow` | Practices | Git branching and workflow |
| `refactoring` | Practices | Safe refactoring techniques |
| `scrum-master` | Process | Agile / Scrum facilitation |
| `architect-role` | Process | Technical leadership patterns |

## Where Files Are Installed

| Path | Contents |
|------|----------|
| `~/.claude/settings.json` | Claude Code settings (UX prefs, hooks, env vars, statusline) |
| `~/.claude/CLAUDE.md` | Global instructions, skill router |
| `~/.claude/statusline.sh` | Statusline script |
| `~/.claude/hooks/subagent-model-router.sh` | Subagent model routing hook |
| `~/.claude/hooks/pre-compact.sh` | Pre-compact instructions hook |
| `~/.claude/skills/<id>/` | Skill directories from registry |
| `~/.claude.json` | MCP server registrations (context-mode) |
| `~/.claude-bootstrap/logs/results.tsv` | Per-component install results |
| `~/.claude-bootstrap/logs/` | Full log output per run |

## Rollback / Backups

Every file modified by a bootstrap script is backed up first:

```
~/.claude/settings.json.bak.20240101_120000
```

Format: `<original-path>.bak.YYYYMMDD_HHMMSS`. To restore, copy the `.bak.*` file back over the original.

Install results are recorded in `results.tsv` with status `OK`, `FAILED`, `SKIPPED`, or `DECLINED`.

## Requirements

- macOS 12+ or Linux (x86_64 or arm64)
- bash 4.0+
- Internet access for downloading components

Bootstrap installs missing dependencies automatically (via Homebrew on macOS, apt-get/dnf/yum on Linux). Hard deps: `curl`, `git`, `python3`, `npm`. Soft deps: `jq`, `pipx`.
