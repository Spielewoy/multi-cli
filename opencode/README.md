# opencode — OpenCode

**Strategy:** `env` — sets `OPENCODE_CONFIG_DIR={profileDir}` and `OPENCODE_CONFIG={profileDir}/opencode.json`.

OpenCode resolves its config and runtime state from these two env vars. Pointing both at the profile dir isolates auth and per-profile customizations.

## Install

```bash
npm i -g opencode-ai
```

## Quickstart

```bash
multi-cli new opencode/work
multi-cli new opencode/personal
opencode-work
opencode-personal
```

## Profile types

- **full** *(default)* — separate `opencode.json`, agents, commands, modes, plugins, auth.
- **shared** — symlinks `agents/`, `commands/`, `modes/`, `plugins/` from `~/.config/opencode/`. Only `auth.json` and per-profile config stay isolated.

## Verified

Smoke-tested live against `opencode 0.26.8` on Windows.
