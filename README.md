# claude-reimagined

A one-command bootstrap that turns a fresh machine into a fully wired Claude Code workstation — CLI, plugins, hooks, MCP servers, statusline, and a 40+ skill library, all configured to work together out of the box.

If you've ever spent an afternoon stitching together Claude Code, RTK, context-mode, code-review-graph, caveman, custom hooks, and a skill router — this repo is that afternoon, automated.

---

## Install

Three steps. macOS or Linux.

```bash
git clone https://github.com/kunaltulsidasani/claude-reimagined.git
cd claude-reimagined
./bootstrap.sh
```

That's it. The bootstrapper will:

1. Detect your OS and check for missing dependencies (`curl`, `git`, `python3`, `npm`, `jq`, `pipx`).
2. Walk through each component, explain what it does, and ask before installing.
3. Print a verification summary at the end.

### Other modes

```bash
./bootstrap.sh --dry-run                              # preview only — no changes
./bootstrap.sh --yes                                  # auto-approve every prompt
./bootstrap.sh --force                                # reinstall components already present
./bootstrap.sh --clean --yes                          # wipe ~/.claude first, then fresh install
./bootstrap.sh --skip rtk,caveman --yes               # skip specific components
./bootstrap.sh --skills-only python-pro,golang-pro    # install only chosen skills
```

---

## What you get, and why

Each component solves a specific pain point with vanilla Claude Code. You can skip any of them with `--skip <id>`.

### `claude-code` — the CLI itself
Claude Code is Anthropic's official CLI. Everything else in this repo plugs into it. If you don't have it, the bootstrapper installs the latest version via `npm`.

### `rtk` — Rust Token Killer
A shell proxy that rewrites your `git`, `ls`, `grep`, etc. through a token-aware filter. Cuts shell-output context usage by **60–90%** on dev operations. Once installed, a hook transparently rewrites `git status` → `rtk git status`, so you don't change how you type commands.
**Why you want it:** Claude burns through context fast on noisy command output. RTK trims the noise before it reaches the model.

### `code-review-graph` — persistent codebase knowledge graph
A Tree-sitter-powered graph of your codebase: functions, classes, calls, imports, tests. Updates incrementally on every file change via a hook. Claude queries the graph instead of re-reading files when it needs structural context.
**Why you want it:** code review and impact analysis without re-grepping the same files every turn. Faster, cheaper, and gives Claude knowledge it physically cannot get from `Grep`.

### `context-mode` — sandboxed command output
An MCP plugin. Large command output (build logs, test runs, JSON dumps) goes into a sandbox FTS5 index instead of flooding the context window. Claude searches the sandbox with FTS queries.
**Why you want it:** a `pytest -v` or `npm run build` shouldn't eat 50k tokens. With context-mode, it eats ~200 — the chunk title and the matching lines.

### `caveman` — terse communication mode
A Claude Code plugin that injects a system prompt telling Claude to drop articles, filler, and pleasantries while keeping all technical substance. ~75% fewer output tokens with no loss of correctness.
**Why you want it:** Claude's default tone is friendly and verbose. Caveman makes it terse without dumbing it down.

### `statusline` — terminal statusline
A shell script that renders the current Claude Code session state — model, token usage, cost — into your terminal statusline.
**Why you want it:** know at a glance whether you're on Opus or Haiku, and how much context is left, without `/status`.

### `subagent-router` — model routing hook
A `PreToolUse` hook that fires before every `Agent` spawn. It inspects the subagent type and prompt, then pins a model: Haiku for cheap lookups (Explore, statusline-setup), Sonnet for general work, Opus only when you explicitly choose it. Saves cost on every spawned agent automatically.
**Why you want it:** you'd never manually pick Haiku for every file-search subagent. The hook does it for you.

### `pre-compact` — context-aware compaction
A `PreCompact` hook that fires right before Claude auto-compacts the context window. It detects your stack (Next.js, Go, FastAPI, Rails, etc.), reads git state, and writes targeted preservation instructions for the summarizer.
**Why you want it:** vanilla compaction drops mid-task state — error messages, files touched, blocked work. With this hook, those things survive every compact, so resuming work is seamless instead of a re-discovery exercise.

### `skills` — 40+ curated skill library
Skills are domain-specific prompting libraries Claude picks up automatically via the skill router. The bootstrapper installs them into `~/.claude/skills/` from community repos via sparse clone.
**Why you want it:** ask Claude "build me a NestJS module" and the `nestjs-expert` skill kicks in with framework-specific patterns. Without skills, you'd hand-write that context every time.

---

## Hooks deep-dive

### `pre-compact` — survive context compaction

**File:** `hooks/pre-compact.sh` → `~/.claude/hooks/pre-compact.sh`

**Fires:** immediately before Claude auto-compacts (triggered at 80% context via `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`).

**Does:** detects your stack, schema files, API directories, and git state, then writes preservation instructions to stdout. Claude's compaction summarizer reads these and decides what to keep.

**Stack detection covers:** JS/TS (Next.js, NestJS, React, Node), Go, Python (FastAPI, Django, Flask), Rust, Flutter, Java/Maven, Kotlin/Gradle, Ruby/Rails, Swift, C#/.NET. Each stack has its own preservation rules — test command, build command, schema file, API dirs.

**The compacted summary is guaranteed to contain:** active task and next step, exact error messages, every file touched, non-obvious decisions and their reasons, pending/blocked work, discovered env constraints.

### `subagent-model-router` — auto-pick the cheapest capable model

**File:** `hooks/subagent-model-router.sh` → `~/.claude/hooks/subagent-model-router.sh`

**Fires:** before every `Agent` tool call.

**Does:** inspects `subagent_type` and prompt complexity, rewrites the tool input via `updatedInput` to pin a specific model.

| Subagent type | Routed model |
|---------------|-------------|
| `Explore`, `statusline-setup`, `claude-code-guide` | Haiku |
| `general-purpose` with simple lookup prompt | Haiku |
| `general-purpose` with complex prompt (implement/debug/design/…) | Sonnet |
| `Plan`, `superpowers:code-reviewer` | Sonnet (floor) |
| everything else | inherits parent model |

---

## Settings (`~/.claude/settings.json`)

This file is **user-managed**, not auto-installed. The bootstrapper verifies it exists at the end. If you don't have one, copy `configs/settings.json.example` (if shipped) or build one with the values below.

| Setting | Value | Why |
|---------|-------|-----|
| `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` | `80` | trigger auto-compact at 80% instead of default 95%, giving the pre-compact hook room to run |
| `skillListingMaxDescChars` | `300` | cap skill descriptions in the listing — keeps the skill router prompt lean |
| `skillListingBudgetFraction` | `0.005` | limit skill listing to 0.5% of context — registry shouldn't burn meaningful tokens |
| `spinnerTipsEnabled` | `false` | disable loading tips — noise |
| `effortLevel` | `medium` | default thinking effort; override per-task with `/effort` |
| `promptSuggestionEnabled` | `false` | disable inline suggestions — they interrupt flow |
| `tui` | `fullscreen` | full-screen TUI instead of inline terminal mode |
| `prefersReducedMotion` | `true` | disable TUI animations |
| `showThinkingSummaries` | `false` | hide extended thinking summaries — reduces noise |
| `autoScrollEnabled` | `false` | disable auto-scroll so output stays readable mid-task |

Hooks registered in `settings.json`:
- `PreCompact` → `pre-compact.sh`
- `PreToolUse[Agent]` → `subagent-model-router.sh`

---

## Skills library

40+ skills installed from community repos via sparse clone. Use `--skills-only <ids>` to pick a subset.

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

---

## Where files land

| Path | Contents |
|------|----------|
| `~/.claude/settings.json` | Claude Code settings (UX prefs, hooks, env vars, statusline) — **user-managed** |
| `~/.claude/CLAUDE.md` | Global instructions, skill router — **user-managed** |
| `~/.claude/statusline.sh` | Statusline script |
| `~/.claude/hooks/subagent-model-router.sh` | Subagent model routing hook |
| `~/.claude/hooks/pre-compact.sh` | Pre-compact instructions hook |
| `~/.claude/skills/<id>/` | Skill directories from registry |
| `~/.claude.json` | MCP server registrations (context-mode) |
| `~/.claude-bootstrap/logs/results.tsv` | Per-component install results |
| `~/.claude-bootstrap/logs/` | Full log output per run |

---

## Rollback

Every file modified by a bootstrap script is backed up first:

```
~/.claude/settings.json.bak.20240101_120000
```

Format: `<original-path>.bak.YYYYMMDD_HHMMSS`. To restore, copy the `.bak.*` file back over the original.

Want a clean reinstall? `./bootstrap.sh --clean --yes` wipes `~/.claude` first.

Install results are recorded in `~/.claude-bootstrap/logs/results.tsv` with status `OK`, `FAILED`, `SKIPPED`, or `DECLINED`.

---

## Requirements

- macOS 12+ or Linux (x86_64 or arm64)
- bash 4.0+
- Internet access for downloads

The bootstrapper installs missing deps automatically (Homebrew on macOS, apt-get/dnf/yum on Linux).

- **Hard deps:** `curl`, `git`, `python3`, `npm`
- **Soft deps:** `jq`, `pipx`

---

## Troubleshooting

**`[FAIL] CLAUDE.md` or `[FAIL] settings`** — these files are user-managed. Create them at `~/.claude/CLAUDE.md` and `~/.claude/settings.json`. The bootstrapper only verifies their existence; it does not install them.

**`rtk gain` fails** — you may have the wrong `rtk` binary on your PATH (there's a name collision with reachingforthejack/rtk). Run `which rtk` to check.

**Component fails mid-bootstrap** — non-critical components don't abort the run. Check `~/.claude-bootstrap/logs/results.tsv` and the per-script logs in the same dir.

---

## Contributing

Tests live in `tests/integration/`. Run them with:

```bash
make test
```

The runner is zero-dep bash. ~140 tests cover every install script.
