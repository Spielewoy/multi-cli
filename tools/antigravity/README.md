# antigravity — Google Antigravity

**Strategy:** `userDataDir` — passes `--user-data-dir={profileDir}` and `--extensions-dir={profileDir}/extensions` on launch.

Antigravity is built on a VS Code/Electron base and accepts the same launch flags. Each profile gets a clean user data dir and extensions dir; Google account auth lives inside the user data dir, so isolation is complete.

## Install

[antigravity.google.com](https://antigravity.google.com/)

## Quickstart

```bash
multi-cli new antigravity/work
multi-cli new antigravity/personal
antigravity-work       # opens a window signed in as Google account A
antigravity-personal   # second window, account B
```

## Profile types

- **full** *(default)* — separate user data dir, separate extensions dir.
- **shared** — symlinks `argv.json` from `~/.antigravity/`. Account state stays isolated.

## Caveats

- The integrated agent browser also stores cookies inside the user data dir — those are isolated too.

## Verified

Smoke-tested live on Windows. Binary version recorded in `tests/results.md`.
