# gemini-cli — Gemini CLI

**Strategy:** `env` — sets `GEMINI_CLI_HOME={profileDir}` before launch.

The official Gemini CLI honors `GEMINI_CLI_HOME` to relocate its `.gemini/` config tree (settings, OAuth credentials, history, skills).

## Install

```bash
npm i -g @google/gemini-cli
```

## Quickstart

```bash
multi-cli new gemini-cli/work
multi-cli new gemini-cli/personal
gemini-cli-work
gemini-cli-personal
```

## Profile types

- **full** *(default)* — separate `oauth_creds.json`, `google_accounts.json`, `settings.json`, `history/`, `skills/`.
- **shared** — symlinks `settings.json`, `skills/`, `GEMINI.md` from `~/.gemini/`. Only OAuth state stays isolated.

## Verified

Smoke-tested live on Windows after `npm i -g @google/gemini-cli`. Specific binary version recorded in `tests/results.md` after the test run.
