# claude-reimagined

Bootstrap system for Claude Code and its plugin ecosystem. Single command installs and wires together Claude Code, RTK, context-mode, code-review-graph, caveman, statusline, subagent router, CLAUDE.md, and a curated skill library on macOS and Linux.

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

| Component | What it does | Skip flag | Verify |
|-----------|-------------|-----------|--------|
| deps | Installs system packages: curl, git, python3, node/npm, jq, pipx | `--skip deps` | all present in PATH |
| claude-code | Claude Code CLI | `--skip claude-code` | `claude --version` |
| rtk | Token-saving proxy — 60–90% context reduction on shell output | `--skip rtk` | `rtk gain` |
| code-review-graph | Persistent codebase knowledge graph for token-efficient reviews | `--skip code-review-graph` | `code-review-graph --version` |
| context-mode | MCP plugin that sandboxes large command output out of main context | `--skip context-mode` | `claude mcp list` |
| caveman | Claude Code plugin — caveman communication mode hooks and UI | `--skip caveman` | `~/.claude/settings.json` |
| statusline | Shell statusline integration showing Claude Code session state | `--skip statusline` | `~/.claude/statusline.sh` |
| subagent-router | PreToolUse hook — routes subagents to optimal model (Haiku/Sonnet) automatically | `--skip subagent-router` | `~/.claude/hooks/` |
| claude-md | Installs global CLAUDE.md with skill router and project conventions | `--skip claude-md` | `~/.claude/CLAUDE.md` |
| settings | Migrates existing settings and applies Claude Code configuration | `--skip migrate-settings` | `~/.claude/settings.json` |
| skills | Installs skills from the registry into `~/.claude/skills/` | `--skip skills` | `~/.claude/skills/` |

## Skills Library

50+ curated skills installed from community repos via sparse clone. Use `--skills-only <ids>` to install a subset.

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

## Subagent Model Router

`hooks/subagent-model-router.sh` intercepts every `Agent` tool call and routes to the cheapest capable model:

| Subagent type | Model |
|---------------|-------|
| `Explore`, `statusline-setup`, `claude-code-guide` | Haiku |
| `general-purpose` with simple lookup prompt | Haiku |
| `general-purpose` with complex prompt (implement/debug/design/…) | Sonnet |
| `Plan`, `superpowers:code-reviewer` | Sonnet (floor) |
| Everything else | inherits parent model |

## Where Files Are Installed

| Path | Contents |
|------|----------|
| `~/.claude/settings.json` | Claude Code settings |
| `~/.claude/CLAUDE.md` | Global instructions, skill router |
| `~/.claude/statusline.sh` | Statusline script |
| `~/.claude/hooks/` | Installed hooks (subagent router, caveman, …) |
| `~/.claude/skills/<id>/` | Skill directories from registry |
| `~/.claude.json` | MCP server registrations (context-mode) |
| `~/.claude-bootstrap/logs/results.tsv` | Per-component install results |
| `~/.claude-bootstrap/logs/` | Full log output |

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
