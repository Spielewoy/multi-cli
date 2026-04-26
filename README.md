# Multi-Codex

**Run multiple OpenAI Codex accounts at the same time.** No more logging in and out — each profile gets its own login, config, and sessions.

Works on **macOS** (Intel + Apple Silicon), **Linux**, and **Windows**.

[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20Windows-lightgrey)](#requirements)

---

## What Does This Do?

Normally, Codex CLI can only be logged into **one account at a time**. Everything lives in a single folder (`~/.codex/`).

Multi-codex fixes this by creating **separate folders** for each profile. When you launch a profile, Codex uses that folder instead of the default — so each profile has its own account, settings, and history.

**Example:** You have a work account and a personal account. Instead of logging out and back in every time you switch, you just run:

```bash
work          # launches Codex with your work account
personal      # launches Codex with your personal account
```

Both can run at the same time. That's it.

---

## Requirements

You need two things installed before using multi-codex:

| Requirement | How to get it |
|-------------|---------------|
| **Node.js** v22 or newer | [nodejs.org](https://nodejs.org/) — download the LTS version |
| **Codex CLI** | After installing Node.js, run: `npm install -g @openai/codex` |

**Not sure if you have them?** Open a terminal and run:
```bash
node --version     # should show v22.x.x or higher
codex --version    # should show a version number
```

---

## Installation

Pick your operating system:

### macOS / Linux

**One-line install** (copy-paste this into Terminal):
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/ProGambler67/multi-codex/main/install.sh)"
```

**Manual install** (if you prefer):
```bash
# Download the script
curl -fsSL https://raw.githubusercontent.com/ProGambler67/multi-codex/main/multi-codex -o /usr/local/bin/multi-codex

# Make it executable
chmod +x /usr/local/bin/multi-codex
```

### Windows

**One-line install** (copy-paste this into PowerShell):
```powershell
irm https://raw.githubusercontent.com/ProGambler67/multi-codex/main/install.ps1 | iex
```

**Manual install** (if you prefer):
1. Download `multi-codex.ps1` to a folder (e.g. `C:\Users\YourName\.local\bin\`)
2. Create a file called `multi-codex.cmd` in the same folder with this content:
   ```
   @echo off
   powershell.exe -ExecutionPolicy Bypass -File "%~dp0multi-codex.ps1" %*
   ```
3. Add that folder to your PATH ([how?](https://www.architectryan.com/2018/03/17/add-to-the-path-on-windows-10/))

---

## Getting Started (Step-by-Step)

### Step 1: Create a profile

```bash
multi-codex new work
```

This creates an isolated profile called `work`. You can name it anything — `personal`, `client-x`, `test`, etc.

### Step 2: Add the profile shortcut to your terminal

When you create a profile, multi-codex tells you to add a folder to your PATH so you can use the profile name as a command. **You only need to do this once.**

**macOS / Linux** — add this line to your shell config:
```bash
echo 'export PATH="$HOME/CodexProfiles/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

> **Using bash instead of zsh?** Replace `~/.zshrc` with `~/.bashrc` in both commands above.

**Windows** — add the folder to your PATH:
```powershell
# Temporary (current session only):
$env:PATH += ";$env:USERPROFILE\CodexProfiles\bin"

# Permanent: open System Properties > Advanced > Environment Variables
# and add  %USERPROFILE%\CodexProfiles\bin  to your PATH
```

### Step 3: Log into Codex with this profile

```bash
work
```

This opens Codex using the `work` profile. The first time, it will ask you to log in. Your login is saved to **this profile only** — it won't affect your other profiles.

### Step 4: Create more profiles

```bash
multi-codex new personal
personal
```

Now you have two independent Codex instances. Each has its own login, config, and session history.

### Step 5: Pass arguments through

You can pass any arguments directly — they get forwarded to Codex:

```bash
work .                    # open Codex in the current directory
work path/to/project      # open a specific project
personal --help           # pass --help to Codex
```

---

## All Commands

### Managing Profiles

| Command | What it does |
|---------|--------------|
| `multi-codex new <name>` | Create a new profile |
| `multi-codex new <name> --shared` | Create a profile that shares config/skills but has its own login |
| `multi-codex new <name> --from <template>` | Create a profile from a saved template |
| `multi-codex list` | Show all your profiles |
| `multi-codex status` | Show which profiles are running, their type, and disk usage |
| `multi-codex rename <old> <new>` | Rename a profile |
| `multi-codex delete <name>` | Delete a profile (asks for confirmation first) |
| `multi-codex clone <source> <copy>` | Make a copy of a profile |

### Templates

Templates let you save a profile's setup and reuse it:

| Command | What it does |
|---------|--------------|
| `multi-codex template save <profile> <name>` | Save a profile as a template |
| `multi-codex template list` | List your templates |
| `multi-codex template delete <name>` | Delete a template |

> **Note:** Templates never copy your login credentials — they're safe to share.

### Backup & Transfer

| Command | What it does |
|---------|--------------|
| `multi-codex export <name>` | Save a profile to a `.tar.gz` (macOS/Linux) or `.zip` (Windows) file |
| `multi-codex import <file> [name]` | Restore a profile from a backup file |

### Tools

| Command | What it does |
|---------|--------------|
| `multi-codex doctor` | Check if everything is set up correctly |
| `multi-codex stats` | Show how much disk space each profile uses |
| `multi-codex update` | Update multi-codex to the latest version |
| `multi-codex completion` | Set up tab-completion for your shell |
| `multi-codex help` | Show help |

---

## First-Time Setup Wizard

If you prefer a guided walkthrough instead of following the steps above, run the setup wizard:

**macOS / Linux:**
```bash
bash setup.sh
```

**Windows:**
```powershell
powershell -ExecutionPolicy Bypass -File setup.ps1
```

It will walk you through checking your install, choosing where to store profiles, and creating your first profiles.

---

## Full vs Shared Profiles

By default, `multi-codex new <name>` creates a **full** profile — completely separate config, skills, agents, and login.

If you just need a second **account** but want to keep using the same config and skills, create a **shared** profile:

```bash
multi-codex new client-x --shared
```

| What's isolated? | Full profile | Shared profile |
|------------------|:---:|:---:|
| Login / accounts | ✅ | ✅ |
| Sessions & history | ✅ | ✅ |
| Config (config.toml) | ✅ | Shared with main |
| Skills | ✅ | Shared with main |
| Agents | ✅ | Shared with main |
| MCP configs | ✅ | Shared with main |

---

## Desktop Shortcuts

When you create a profile, multi-codex also creates a clickable shortcut so you can launch it without the terminal:

| Platform | Where the shortcut lives |
|----------|--------------------------|
| macOS | `~/Applications/Multicodex <name>.app` (shows up in Launchpad) |
| Linux | Shows up in your app menu (GNOME, KDE, etc.) |
| Windows | Start Menu → `Multi-codex <name>` |

---

## Shell Tab-Completion

Enable tab-completion so you can press Tab to autocomplete profile names and commands:

```bash
multi-codex completion
```

Follow the instructions it shows. Works with bash, zsh, and PowerShell.

---

## Profile Name Rules

Profile names can contain **letters**, **numbers**, and **hyphens**. They must start with a letter or number.

```
✅  work        personal       client-1       my-project
❌  -bad        my_profile     hello world    work!
```

---

## Where Profiles Are Stored

All profiles live in one folder:

| Platform | Default location |
|----------|-----------------|
| macOS / Linux | `~/CodexProfiles/` |
| Windows | `%USERPROFILE%\CodexProfiles\` |

You can change this by setting the `MULTICODEX_HOME` environment variable.

---

## Troubleshooting

### "command not found" when typing a profile name

You need to add the profiles `bin` folder to your PATH. See [Step 2 above](#step-2-add-the-profile-shortcut-to-your-terminal).

You can also run `multi-codex doctor` to check what's missing.

### "Codex not found"

Install Codex CLI:
```bash
npm install -g @openai/codex
```

Or if you installed Codex somewhere unusual, tell multi-codex where it is:
```bash
export MULTICODEX_APP=/path/to/codex
```

### Something else is wrong

Run the built-in diagnostics:
```bash
multi-codex doctor
```

This checks your Node.js version, Codex installation, PATH setup, and profile storage.

---

## Uninstall

**macOS / Linux:**
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/ProGambler67/multi-codex/main/uninstall.sh)"
```

**Windows:**
```powershell
irm https://raw.githubusercontent.com/ProGambler67/multi-codex/main/uninstall.ps1 | iex
```

You'll be asked whether to delete your profile data — nothing is removed without your confirmation.

---

## Environment Variables

| Variable | What it does |
|----------|--------------|
| `MULTICODEX_HOME` | Change where profiles are stored (default: `~/CodexProfiles`) |
| `MULTICODEX_APP` | Point to a custom Codex binary or app path |
| `CODEX_HOME` | Used internally — you don't need to set this yourself |

---

## Project Files

```
multi-codex/
├── multi-codex          # Main CLI — macOS & Linux (bash)
├── multi-codex.ps1      # Main CLI — Windows (PowerShell)
├── setup.sh             # Setup wizard — macOS & Linux
├── setup.ps1            # Setup wizard — Windows
├── install.sh           # Installer — macOS & Linux
├── install.ps1          # Installer — Windows
├── uninstall.sh         # Uninstaller — macOS & Linux
├── uninstall.ps1        # Uninstaller — Windows
├── icon.icns            # macOS app icon
└── README.md
```
