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

### Languages
`python-pro` · `typescript-pro` · `golang-pro` · `rust-pro` · `java-architect` · `kotlin-specialist` · `swift-expert` · `csharp-developer` · `cpp-pro` · `php-pro` · `ruby-rails` · `elixir-pro` · `react` · `vue-expert` · `angular-architect` · `nextjs-developer` · `nestjs-expert` · `django-expert` · `fastapi-expert` · `laravel-specialist` · `flutter-expert`

### Databases
`postgres-pro` · `redis-pro` · `dynamodb-pro` · `mongodb-pro` · `database-designer`

### Cloud / Infrastructure
`aws-solution-architect` · `terraform` · `kubernetes-ops` · `docker` · `ci-cd`

### Testing
`tdd` · `bdd` · `unit-tests` · `test-automation`

### API / Architecture
`api-designer` · `openapi-docs` · `api-security` · `system-design`

### Engineering Practices
`code-reviewer` · `security-review` · `debugging` · `git-workflow` · `refactoring`

### Planning / Process
`scrum-master` · `architect-role`

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
- `curl`
- `jq` (for subagent router hook)
- `npm` (for claude-code installation)
- Internet access for downloading components
