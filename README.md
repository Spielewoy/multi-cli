# multi-cli

**Run multiple sandboxed profiles of any AI coding CLI or agent IDE — simultaneously.**

No more logging in and out. Launch as many profiles as you need, all at once. Each gets its own auth, config, sessions, and extensions.

[![GitHub repository](https://img.shields.io/badge/GitHub-Repository-blue?logo=github)](https://github.com/Spielewoy/multi-codex)
[![GitHub profile](https://img.shields.io/badge/GitHub-Profile-lightgrey?logo=github)](https://github.com/Spielewoy)
[![GitHub stars](https://img.shields.io/github/stars/Spielewoy/multi-codex?style=social)](https://github.com/Spielewoy/multi-codex/stargazers)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20Windows-lightgrey)](#install)
[![License](https://img.shields.io/badge/license-MIT-green)](#license)

---

## Supported Tools

| Tool | Kind | Isolation | Status |
|------|------|-----------|--------|
| [Claude Code](tools/claude-cli/) | CLI | `env` (`CLAUDE_CONFIG_DIR`) | stable |
| [OpenAI Codex CLI](tools/codex/) | CLI | `env` (`CODEX_HOME`) | stable |
| [OpenCode](tools/opencode/) | CLI | `env` (`OPENCODE_CONFIG_DIR`) | stable |
| [Gemini CLI](tools/gemini-cli/) | CLI | `env` (`GEMINI_CLI_HOME`) | stable |
| [Command Code](tools/commandcode/) | CLI | `redirectHome` | stable |
| [Cursor](tools/cursor/) | IDE | `userDataDir` | stable |
| [Antigravity](tools/antigravity/) | IDE | `userDataDir` | stable |

Each tool has its own folder under `tools/` with an `adapter.json` describing how isolation works.

---

## Install

**macOS / Linux**

```bash
curl -fsSL https://raw.githubusercontent.com/Spielewoy/multi-codex/main/install.sh | bash
```

**Windows** — open PowerShell and run:

```powershell
irm https://raw.githubusercontent.com/Spielewoy/multi-codex/main/install.ps1 | iex
```

### From source

```bash
git clone https://github.com/Spielewoy/multi-codex.git
cd multi-codex
./install.sh --local        # macOS/Linux
.\install.ps1 -Local        # Windows
```

**Requirement (macOS/Linux):** [jq](https://jqlang.github.io/jq/) must be installed (`brew install jq` / `apt install jq`).

---

## Quick Start

```bash
# Create a profile
multi-cli new claude-cli/work

# Launch it
multi-cli launch claude-cli/work

# Or use the shorthand
multi-cli claude-cli/work
```

Each profile gets an automatic shell alias:

| Platform | Location |
|----------|----------|
| macOS / Linux | `~/MultiCliProfiles/bin/` (add to `PATH`) |
| Windows | Start Menu shortcuts created automatically |

---

## Commands

### Profile Management

| Command | Description |
|---------|-------------|
| `multi-cli new <tool>/<name>` | Create a new isolated profile |
| `multi-cli new <tool>/<name> --shared` | Create a lightweight profile (shared settings, isolated auth) |
| `multi-cli new <tool>/<name> --from <tpl>` | Create from a saved template |
| `multi-cli <tool>/<name>` | Launch a profile (shorthand) |
| `multi-cli launch <tool>/<name>` | Launch a profile |
| `multi-cli list [<tool>]` | List all profiles |
| `multi-cli status` | Show running state, type, last used, and size |
| `multi-cli clone <tool>/<src> <tool>/<dest>` | Copy an existing profile |
| `multi-cli rename <tool>/<old> <tool>/<new>` | Rename a profile |
| `multi-cli delete <tool>/<name>` | Delete a profile and all its data |

### Templates

| Command | Description |
|---------|-------------|
| `multi-cli template save <tool>/<profile> <name>` | Save a profile as a reusable template |
| `multi-cli template list` | List saved templates |
| `multi-cli template delete <name>` | Remove a template |

### Backup & Transfer

| Command | Description |
|---------|-------------|
| `multi-cli export <tool>/<name> [path]` | Archive a profile to `.tar.gz` (`.zip` on Windows) |
| `multi-cli import <archive> <tool>/<name>` | Restore a profile from an archive |

### Utilities

| Command | Description |
|---------|-------------|
| `multi-cli tools` | List all supported tools and their install status |
| `multi-cli stats` | Show disk usage per profile |
| `multi-cli doctor` | Diagnose your environment |
| `multi-cli completion {bash\|zsh\|powershell}` | Set up shell tab-completion |
| `multi-cli help` | Show help |
| `multi-cli version` | Show version |

---

## How Isolation Works

multi-cli uses four strategies depending on what the tool supports:

| Strategy | How it works | Used by |
|----------|-------------|---------|
| `env` | Sets a config-dir environment variable before launch | Claude Code, Codex, OpenCode, Gemini CLI |
| `userDataDir` | Passes `--user-data-dir` and `--extensions-dir` flags | Cursor, Antigravity |
| `redirectHome` | Points `HOME`/`USERPROFILE` at a per-profile dir, symlinks shared dotfiles back | Command Code |
| `appdata` | Redirects `%APPDATA%` only (Windows) | *(reserved)* |

Each tool's `tools/<id>/adapter.json` declares which strategy to use. The launcher reads the adapter and applies it automatically.

---

## Profile Types

| Flag | Meaning |
|------|---------|
| *(none)* | **Full** — completely isolated. Fresh auth, fresh config. |
| `--shared` | **Shared** — symlinks settings/extensions from your main install. Auth stays isolated. |
| `--cli` | **CLI** — marks the profile for terminal-only launch (skips GUI discovery). |
| `--from <tpl>` | Clone from a saved template. |

---

## Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `MULTICLI_HOME` | `~/MultiCliProfiles` | Where all profiles are stored |
| `MULTICLI_OVERRIDE_BINARY` | *(unset)* | Force a specific binary path for the next launch |
| `MULTICLI_REPO` | *(unset)* | Git URL for remote install |
| `MULTICLI_PLATFORM` | *(auto)* | Override platform detection (`darwin`, `linux`) |

---

## Diagnostics

```bash
multi-cli doctor
```

Checks that your profile storage exists, alias directory is in PATH, and each tool's binary is detected (or shows an install hint).

---

## Shell Completion

Enable tab-completion for commands and profile names:

```bash
multi-cli completion bash   # or zsh, powershell
```

Follow the instructions to add it to your `.zshrc`, `.bashrc`, or PowerShell `$PROFILE`.

---

## Backward Compatibility

If you used the original `multi-codex` tool, the legacy shims still work:

```bash
multi-codex new work        # same as: multi-cli new codex/work
multi-codex work            # same as: multi-cli launch codex/work
```

---

## Uninstall

**macOS / Linux**

```bash
curl -fsSL https://raw.githubusercontent.com/Spielewoy/multi-codex/main/uninstall.sh | bash
```

**Windows**

```powershell
irm https://raw.githubusercontent.com/Spielewoy/multi-codex/main/uninstall.ps1 | iex
```

You'll be asked whether to remove your profile data — nothing is deleted without confirmation.

---

## Credits

- **Creator** — [Spielewoy](https://github.com/Spielewoy)

---

## License

[MIT](LICENSE)
