# antigravity — Google Antigravity

**Strategy:** `appdata` — redirects `%APPDATA%` to a per-profile directory so Antigravity's state (stored under `%APPDATA%\Antigravity`) is isolated per profile.

Antigravity 2.0 is an Electron-based IDE that stores everything (auth, settings, session state) under `%APPDATA%\Antigravity` on Windows, `~/Library/Application Support/Antigravity` on macOS, and `~/.config/Antigravity` on Linux. The `appdata` strategy overrides the environment variable so each profile gets its own user data directory.

**For CLI workflows**, use the companion AGY-CLI adapter (`multi-cli new agy-cli/work`) which provides full terminal-based isolation via `redirectHome`.

## Install

[antigravity.google.com](https://antigravity.google.com/) — download the Antigravity 2.0 installer which includes both the Antigravity IDE and AGY-CLI (Antigravity-CLI).

## Quickstart

```bash
multi-cli new antigravity/work
multi-cli new antigravity/personal
antigravity-work       # opens IDE window with isolated account
antigravity-personal   # separate window, different account
```

## Profile types

- **full** *(default)* — redirected `%APPDATA%` pointing to per-profile directory. Auth, settings, and extensions are isolated.
- **shared** — symlinks `argv.json` from `~/.antigravity/`. Account state stays isolated.
- **cli** — marks profile as CLI-only (skips GUI shortcuts).

## Antigravity 2.0 notes

- Antigravity 2.0 spawns a `language_server.exe` process with `--app_data_dir antigravity`. This flag is internal and the server resolves its data directory relative to the Electron `app.getPath('userData')` call, which on Windows uses the `%APPDATA%` registry key rather than the environment variable.
- The `appdata` strategy overrides the `APPDATA` environment variable before launch.
- Full verification of complete isolation (config files being written to the redirected directory) requires additional investigation.
- The `--user-data-dir` and `--extensions-dir` flags from older Antigravity/VSCode forks do not work on Antigravity 2.0.

## Caveats

- The integrated agent browser stores cookies inside the user data dir — those should be isolated too.
- On macOS/Linux, the isolation strategy may differ based on where Antigravity stores its application data.

## Verified

- Binary detection verified on Windows with Antigravity 2.0.1 installed at `%LOCALAPPDATA%\Programs\Antigravity\Antigravity.exe`.
- Full profile isolation effectiveness under active investigation for Antigravity 2.0.
- AGY-CLI isolation fully verified via redirectHome strategy (see `agy-cli/`).
