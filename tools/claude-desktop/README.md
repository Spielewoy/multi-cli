# claude-desktop — Claude Desktop (BETA)

**Status:** `beta` — the strategy is implemented, but not yet verified live in this repo's smoke tests because the desktop app wasn't installed on the test machine.

**Strategy:** `redirectHome` — launches with `HOME` / `USERPROFILE` redirected to a per-profile fake home that contains a synthesized `AppData/Roaming/Claude/` folder.

Claude Desktop has no documented profile flag and stores everything under `%APPDATA%\Claude\` (Windows) or `~/Library/Application Support/Claude/` (macOS). Redirecting the home directory is currently the only known way to run two accounts side-by-side.

## Install

[claude.ai/download](https://claude.ai/download)

## Quickstart

```bash
multi-cli new claude-desktop/work
multi-cli new claude-desktop/personal
claude-desktop-work
claude-desktop-personal
```

## Profile types

- **full** *(default)* — separate fake home with its own `AppData/Roaming/Claude/`.
- **shared** — symlinks `claude_desktop_config.json` (MCP server defs) from the system install.

## Caveats

- **Beta:** if you successfully run two profiles concurrently, please confirm with `multi-cli doctor --verify claude-desktop` and open an issue with the result so this adapter can be promoted to `stable`.
- macOS: redirecting `HOME` while the bundled app is also running from the original `HOME` may show first-launch onboarding twice. Quit the original instance first if you see this.
