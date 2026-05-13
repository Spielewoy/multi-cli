#!/bin/bash
# =============================================================================
# Multi-Codex Installer (macOS / Linux)
#
# What this does:
#   1. Downloads the "multi-codex" script from GitHub
#   2. Puts it in /usr/local/bin (or ~/.local/bin if you don't have sudo)
#   3. Makes it executable
#   4. On macOS, also downloads an icon for app shortcuts
#
# Usage:
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Spielewoy/multi-codex/main/install.sh)"
#
# Or just copy the multi-codex script manually:
#   cp multi-codex /usr/local/bin/ && chmod +x /usr/local/bin/multi-codex
# =============================================================================

set -euo pipefail

REPO="Spielewoy/multi-codex"
BRANCH="main"
RAW="https://raw.githubusercontent.com/$REPO/$BRANCH"

# Where to install the binary. Prefer /usr/local/bin (system-wide).
INSTALL_DIR="/usr/local/bin"

# ── helpers ──────────────────────────────────────────────────────────────────

# Print an indented step message.
print_step () { echo "  → $1"; }

# Print an error and exit.
abort ()       { echo "Error: $1" >&2; exit 1; }

# ── detect platform ─────────────────────────────────────────────────────────
# We only support macOS and Linux. Windows users should use install.ps1.

case "$(uname -s)" in
  Darwin)
    PLATFORM="darwin"
    ;;
  Linux)
    PLATFORM="linux"
    ;;
  *)
    abort "unsupported platform. Multi-codex currently supports macOS and Linux. Windows users: use install.ps1."
    ;;
esac

# ── check that curl is available ─────────────────────────────────────────────

command -v curl &>/dev/null || abort "curl is required but not found"

# ── choose install directory ─────────────────────────────────────────────────
# If /usr/local/bin isn't writable (no sudo), fall back to ~/.local/bin
# and make sure it's in the user's PATH.

if [ ! -w "$INSTALL_DIR" ]; then
  INSTALL_DIR="$HOME/.local/bin"
  mkdir -p "$INSTALL_DIR"

  # If ~/.local/bin isn't already in PATH, add it to the user's shell profile.
  if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    # Figure out which shell config file to update.
    case "${SHELL:-}" in
      */zsh)  SHELL_RC="$HOME/.zshrc" ;;
      */fish) SHELL_RC="$HOME/.config/fish/config.fish" ;;
      *)      SHELL_RC="$HOME/.bashrc" ;;
    esac

    # Build the right PATH export command for the user's shell.
    LINE='export PATH="$HOME/.local/bin:$PATH"'

    if [ "$SHELL_RC" = "$HOME/.config/fish/config.fish" ]; then
      LINE='fish_add_path "$HOME/.local/bin"'
    fi

    # Only add the line if it's not already there.
    if ! grep -qF "$HOME/.local/bin" "$SHELL_RC" 2>/dev/null; then
      echo "" >> "$SHELL_RC"
      echo "# Added by Multi-codex installer" >> "$SHELL_RC"
      echo "$LINE" >> "$SHELL_RC"
      print_step "Added $INSTALL_DIR to PATH in $SHELL_RC"
    fi

    # Apply to the current session so the user can use it right away.
    export PATH="$INSTALL_DIR:$PATH"
  fi
fi

echo "Installing Multi-codex to $INSTALL_DIR ..."

# ── download the multi-codex script ─────────────────────────────────────────

print_step "Downloading multi-codex..."
curl -fsSL "$RAW/multi-codex" -o "$INSTALL_DIR/multi-codex"
chmod +x "$INSTALL_DIR/multi-codex"

# ── download macOS icon (optional — used for .app shortcuts) ─────────────────

if [ "$PLATFORM" = "darwin" ]; then
  print_step "Downloading icon..."
  curl -fsSL "$RAW/icon.icns" -o "$INSTALL_DIR/icon.icns" 2>/dev/null || true
fi

# ── done! ────────────────────────────────────────────────────────────────────

echo ""
echo "✓ Multi-codex installed successfully!"
echo ""
echo "Reload your shell to apply PATH changes:"
echo "  source ~/.zshrc   (or ~/.bashrc, or open a new terminal)"
echo ""
echo "Usage:"
echo "  multi-codex help"
echo "  multi-codex new <profile-name>"
echo "  multi-codex <profile-name>"

# If Codex CLI itself isn't installed, remind the user.
if [ "$PLATFORM" = "linux" ] && ! command -v codex &>/dev/null; then
  echo ""
  echo "Note:"
  echo "  Codex CLI was not found on this machine."
  echo "  Install it (npm install -g @openai/codex) or set MULTICODEX_APP."
fi
