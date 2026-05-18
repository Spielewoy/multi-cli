# claude-cli — Claude Code

**Strategy:** `env` — sets `CLAUDE_CONFIG_DIR={profileDir}` before launch.

Claude Code reads its entire config tree (settings, credentials, history, MCP state, plugins) from `CLAUDE_CONFIG_DIR`, defaulting to `~/.claude/`. Per-profile dirs give clean account isolation.

## Install

```bash
npm i -g @anthropic-ai/claude-code
```

## Quickstart

```bash
multi-cli new claude-cli/work
multi-cli new claude-cli/personal
claude-cli-work       # /login on first run
claude-cli-personal   # different account; runs concurrently
```

## Profile types

- **full** *(default)* — separate `settings.json`, `.credentials.json`, `skills/`, `agents/`, `plugins/`, `commands/`, `todos/`, `projects/`, `history.jsonl`.
- **shared** — symlinks `settings.json`, `skills/`, `agents/`, `plugins/`, `commands/` from `~/.claude/`. Only credentials and history stay isolated.

## Verified

Smoke-tested live against `Claude Code 2.1.143` on Windows.
