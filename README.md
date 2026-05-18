# multi-cli

Run multiple sandboxed profiles of any supported AI CLI or agent IDE -- simultaneously.

Each profile gets its own auth, config, sessions, and extensions. Switch between work accounts, client projects, or personal setups without logging in and out.

## Supported tools

| Tool | Kind | Isolation | Multi-instance |
|------|------|-----------|----------------|
| [Claude Code](tools/claude-cli/) | CLI | `env` (`CLAUDE_CONFIG_DIR`) | yes |
| [OpenAI Codex CLI](tools/codex/) | CLI | `env` (`CODEX_HOME`) | yes |
| [OpenCode](tools/opencode/) | CLI | `env` (`OPENCODE_CONFIG_DIR`) | yes |
| [Gemini CLI](tools/gemini-cli/) | CLI | `env` (`GEMINI_CLI_HOME`) | yes |
| [Command Code](tools/commandcode/) | CLI | `redirectHome` | yes |
| [Cursor](tools/cursor/) | IDE | `userDataDir` | yes |
| [Antigravity](tools/antigravity/) | IDE | `userDataDir` | yes |
| [Claude Desktop](tools/claude-desktop/) | Desktop | `redirectHome` | beta |

Each tool has its own folder under `tools/` with an `adapter.json` describing exactly how isolation works and a README with gotchas.

## Quick start

### Windows (PowerShell)

```powershell
# Install locally
.\install.ps1 -Local

# Create a profile
multi-cli new claude-cli/work

# Launch it
multi-cli launch claude-cli/work

# Or use the shorthand
multi-cli claude-cli/work
```

### macOS / Linux

```bash
# Install locally
./install.sh --local

# Create a profile
multi-cli new claude-cli/work

# Launch it
multi-cli launch claude-cli/work
```

**Requirement (macOS/Linux):** [jq](https://jqlang.github.io/jq/) must be installed (`brew install jq` / `apt install jq`).

## Install

### From source (recommended)

```bash
git clone https://github.com/<owner>/<repo>.git
cd multi-cli
./install.sh --local        # macOS/Linux
# or
.\install.ps1 -Local        # Windows
```

### Remote install

```bash
export MULTICLI_REPO=https://github.com/<owner>/<repo>
curl -fsSL https://raw.githubusercontent.com/<owner>/<repo>/main/install.sh | bash
```

## Commands

```
multi-cli new <tool>/<name> [--shared] [--cli] [--from <tpl>]
multi-cli launch <tool>/<name> [-- args...]
multi-cli list [<tool>]
multi-cli status
multi-cli rename <tool>/<old> <tool>/<new>
multi-cli delete <tool>/<name>
multi-cli clone <tool>/<src> <tool>/<dest>
multi-cli template save <tool>/<profile> <name>
multi-cli template list
multi-cli template delete <name>
multi-cli export <tool>/<name> [path]
multi-cli import <archive> <tool>/<name>
multi-cli tools
multi-cli doctor
multi-cli stats
multi-cli completion {bash|zsh|powershell}
multi-cli help
multi-cli version
```

### Shorthand

```bash
multi-cli claude-cli/work          # same as: multi-cli launch claude-cli/work
multi-cli codex/acme -- --version  # pass flags to the underlying binary
```

### Auto-generated aliases

When you create a profile, a shell alias is placed in `~/MultiCliProfiles/bin/`. Add that to your `PATH` and you get direct commands:

```bash
claude-cli-work       # launches claude-cli/work profile
codex-acme            # launches codex/acme profile
cursor-personal       # launches cursor/personal profile
```

On Windows, Start Menu shortcuts are also created automatically.

## Profile types

| Flag | Meaning |
|------|---------|
| *(none)* | **Full** -- completely isolated. Fresh auth, fresh config. |
| `--shared` | **Shared** -- symlinks settings/skills/plugins from your main install. Auth stays isolated. |
| `--cli` | **CLI** -- marks the profile for terminal-only launch (skips GUI discovery). |
| `--from <tpl>` | Clone from a saved template. |

## How isolation works

multi-cli uses four strategies depending on what the tool supports:

| Strategy | How it works | Used by |
|----------|-------------|---------|
| `env` | Sets a config-dir environment variable before launch | Claude Code, Codex, OpenCode, Gemini CLI |
| `userDataDir` | Passes `--user-data-dir` and `--extensions-dir` flags | Cursor, Antigravity |
| `redirectHome` | Points `HOME`/`USERPROFILE` at a per-profile dir, symlinks shared dotfiles back | Command Code, Claude Desktop |
| `appdata` | Redirects `%APPDATA%` only (Windows) | *(reserved)* |

Each tool's `tools/<id>/adapter.json` declares which strategy to use. The launcher reads the adapter and applies it automatically.

## Environment variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `MULTICLI_HOME` | `~/MultiCliProfiles` | Where all profiles are stored |
| `MULTICLI_OVERRIDE_BINARY` | *(unset)* | Force a specific binary path for the next launch |
| `MULTICLI_REPO` | *(unset)* | Git URL for remote install |
| `MULTICLI_PLATFORM` | *(auto)* | Override platform detection (`darwin`, `linux`) |

## Diagnostics

```bash
multi-cli doctor
```

Checks:
- Profile storage directory exists and is writable
- Alias directory is in PATH
- Each supported tool's binary is detected (or shows install hint)

## Backward compatibility

If you used the original `multi-codex` tool, the `multi-codex` / `multi-codex.ps1` shims still work. They delegate to `multi-cli codex <args>`.

```bash
multi-codex new work        # same as: multi-cli new codex/work
multi-codex work             # same as: multi-cli launch codex/work
```

## Testing

Real launch smoke tests verify that each tool's isolation actually works -- profiles are created, binaries are launched with `--version`, and we confirm that config files land in the profile directory, not the system home.

```powershell
# Windows
.\tests\smoke.ps1

# macOS/Linux
./tests/smoke.sh
```

## Uninstall

```bash
./uninstall.sh          # macOS/Linux
.\uninstall.ps1         # Windows
```

Prompts before removing profiles. Your profile data at `~/MultiCliProfiles` is never deleted without confirmation.

## License

[MIT](LICENSE)
