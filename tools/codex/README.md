# codex — OpenAI Codex CLI

**Strategy:** `env` — sets `CODEX_HOME={profileDir}` before launch.

Codex stores everything (auth, config, sessions) under `~/.codex/` by default, but always checks `CODEX_HOME` first. Pointing it at a profile directory gives full account isolation with zero side effects.

## Install

```bash
npm i -g @openai/codex
```

## Quickstart

```bash
multi-cli new codex/work
multi-cli new codex/personal
codex-work       # logs into account A on first run
codex-personal   # logs into account B; both can run simultaneously
```

## Profile types

- **full** *(default)* — fresh `CODEX_HOME`, separate auth/config/sessions/skills.
- **shared** — symlinks `config.toml`, `skills/`, `agents/`, `prompts/`, `mcp-configs/`, `plugins/` from `~/.codex/`. Only `auth.json` and `sessions/` stay isolated.

## Verified

Smoke-tested live against `codex-cli 0.130.0` on Windows.
