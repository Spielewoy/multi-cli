#!/bin/bash
# =============================================================================
# Multi-Codex Uninstaller (macOS / Linux)
#
# What this does:
#   1. Removes the multi-codex binary from wherever it's installed
#   2. Removes any macOS .app shortcuts or Linux .desktop shortcuts
#   3. Optionally removes all profile data (asks first — nothing is deleted
#      without confirmation)
#
# Usage:
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/ProGambler67/multi-codex/main/uninstall.sh)"
#
# Or just run it directly:
#   bash uninstall.sh
# =============================================================================

set -euo pipefail

# ── helpers ──────────────────────────────────────────────────────────────────

# Print an indented step message.
print_step () { echo "  → $1"; }

# Print an error and exit.
abort ()       { echo "Error: $1" >&2; exit 1; }

echo "Uninstalling Multi-codex..."
echo ""

# ── find and remove the binary ───────────────────────────────────────────────
# First try to find it via the shell's command lookup, then check common paths.

BINARY="$(command -v multi-codex 2>/dev/null || true)"

if [ -n "$BINARY" ]; then
  print_step "Removing $BINARY"
  rm -f "$BINARY"

  # Also remove the icon file if it was installed alongside the binary.
  ICON="$(dirname "$BINARY")/icon.icns"
  if [ -f "$ICON" ]; then
    rm -f "$ICON"
  fi
else
  # Didn't find it in PATH — check the two most common install locations.
  for candidate in /usr/local/bin/multi-codex "$HOME/.local/bin/multi-codex"; do
    if [ -f "$candidate" ]; then
      print_step "Removing $candidate"
      rm -f "$candidate"
      BINARY="$candidate"
      break
    fi
  done

  if [ -z "${BINARY:-}" ]; then
    echo "  multi-codex binary not found (already removed?)"
  fi
fi

# ── remove macOS app shortcuts ───────────────────────────────────────────────
# These are the .app bundles in ~/Applications/ that we create for each profile.

if [ "$(uname -s)" = "Darwin" ]; then
  for app in "$HOME/Applications/Multicodex "*.app; do
    if [ -d "$app" ]; then
      print_step "Removing shortcut: $app"
      rm -rf "$app"
    fi
  done
fi

# ── remove Linux shortcuts ──────────────────────────────────────────────────
# These are the .desktop files (app menu entries) and launcher scripts.

if [ "$(uname -s)" = "Linux" ]; then
  # Remove .desktop files from the applications directory.
  for desktop in "$HOME/.local/share/applications/multicodex-"*.desktop; do
    if [ -f "$desktop" ]; then
      print_step "Removing shortcut: $desktop"
      rm -f "$desktop"
    fi
  done

  # Remove the launcher scripts directory.
  LAUNCHER_DIR="$HOME/.local/share/multicodex"
  if [ -d "$LAUNCHER_DIR" ]; then
    print_step "Removing launcher dir: $LAUNCHER_DIR"
    rm -rf "$LAUNCHER_DIR"
  fi
fi

# ── optionally remove profile data ──────────────────────────────────────────
# This is where all the actual Codex configs, auth tokens, and sessions live.
# We NEVER delete this without asking first.

BASE="${MULTICODEX_HOME:-$HOME/CodexProfiles}"

if [ -d "$BASE" ]; then
  echo ""
  read -r -p "Also delete all profile data in $BASE? [y/N] " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    print_step "Removing $BASE"
    rm -rf "$BASE"
  else
    echo "  Profile data kept at $BASE"
  fi
fi

echo ""
echo "✓ Multi-codex uninstalled."
