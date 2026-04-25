# claude-reimagined

A bootstrap system for Claude Code and its plugin ecosystem. Installs and configures Claude Code, RTK, code-review-graph, context-mode, caveman, and statusline on macOS and Linux with a single command.

## Quick Start

```bash
./bootstrap.sh                        # interactive install
./bootstrap.sh --dry-run              # preview what would happen
./bootstrap.sh --force                # reinstall everything
./bootstrap.sh --yes                  # non-interactive (auto-approve all)
./bootstrap.sh --skip rtk             # skip a component
./bootstrap.sh --skip rtk,caveman --yes  # skip multiple, non-interactive
```

## Components

| Component | What it does | Skip flag | Verify |
|-----------|-------------|-----------|--------|
| claude-code | Claude Code CLI | `--skip claude-code` | `claude --version` |
| rtk | Token-saving proxy for Claude Code | `--skip rtk` | `rtk gain` |
| code-review-graph | Codebase knowledge graph for reviews | `--skip code-review-graph` | `code-review-graph --version` |
| context-mode | MCP plugin for context sandboxing | `--skip context-mode` | `claude mcp list` |
| caveman | Claude Code plugin (hooks/UI) | `--skip caveman` | `~/.claude/settings.json` |
| statusline | Shell statusline integration | `--skip statusline` | `~/.claude/statusline.sh` |
| settings | Migrate and apply claude settings | `--skip migrate-settings` | `~/.claude/settings.json` |

## Where Files Are Installed

- `~/.claude/settings.json` — Claude Code settings
- `~/.claude/statusline.sh` — statusline script
- `~/.claude/plugins/` — caveman plugin directory
- `~/.claude.json` — MCP server registrations (context-mode)
- `~/.claude-bootstrap/logs/results.tsv` — bootstrap results log
- `~/.claude-bootstrap/logs/` — all log output

## Rollback / Backups

Any file modified by bootstrap scripts is backed up before changes:

```
~/.claude/settings.json.bak.20240101_120000
```

Backups use the format `<original-path>.bak.YYYYMMDD_HHMMSS`. To restore, copy the `.bak.*` file back over the original.

All bootstrap activity is logged to `~/.claude-bootstrap/logs/`. The `results.tsv` file records each component's final status (OK, FAILED, SKIPPED, or DECLINED) with a timestamp.

## Requirements

- macOS 12+ or Linux (x86_64 or arm64)
- bash 4.0+
- `curl`
- `npm` (for claude-code installation)
- Internet access for downloading components
