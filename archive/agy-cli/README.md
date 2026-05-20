# AGY-CLI — Antigravity-CLI

**Strategy:** `redirectHome` — overrides `HOME`/`USERPROFILE` to a per-profile `_home/` directory and symlinks whitelisted dotfiles from the real home.

AGY-CLI (Antigravity-CLI) is the CLI companion to Antigravity 2.0. It has no config dir override flag or environment variable, so the only way to isolate it is to redirect its entire home directory. Multi-cli creates a `_home/` per profile and symlinks `.gitconfig`, `.ssh`, `.npmrc` etc. back so that git/SSH/npm work inside the sandbox without re-authenticating.

## Install

[antigravity.google.com](https://antigravity.google.com/)

Download the Antigravity 2.0 installer which includes both the Antigravity IDE and AGY-CLI. On Windows, the binary installs to `%LOCALAPPDATA%\agy\bin\agy.exe`.

## Quickstart

```bash
multi-cli new agy-cli/work
multi-cli new agy-cli/personal
agy-cli-work       # isolated CLI session for your work account
agy-cli-personal   # separate session for your personal account
```

## Profile types

- **full** *(default)* — fresh `_home/` directory with only whitelisted dotfiles symlinked. Auth, config, and conversations are completely isolated.
- **shared** — symlinks `plugins/` from `~/.agy/`. Auth and conversations stay isolated.
- **cli** — marks the profile as CLI-only (no GUI shortcuts generated).

## Caveats

- AGY-CLI stores its state under `$HOME/.agy/` (on Windows: `%USERPROFILE%\.agy\`). Since we redirect the entire home directory, this is automatically isolated.
- Some plugins may write to absolute paths outside `$HOME` — those are not sandboxed.
- On Windows, Developer Mode must be enabled for symlink creation. If unavailable, shared dotfiles are copied instead.

## Verified

Smoke-tested on Windows via `tests/smoke.ps1`. AGY-CLI v1.0.0 detected at `%LOCALAPPDATA%\agy\bin\agy.exe`, redirectHome isolation confirmed.
