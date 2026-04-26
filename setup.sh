#!/usr/bin/env bash
# =============================================================================
# Multi-Codex Interactive Setup Wizard (macOS / Linux)
#
# This script walks a new user through setting up multi-codex step by step.
# It's designed to be as beginner-friendly as possible — every question has
# a sensible default, and you can just press Enter to accept defaults.
#
# What it does:
#   1. Welcomes you and explains what multi-codex is
#   2. Checks that Node.js and Codex CLI are installed
#   3. Installs multi-codex if it's not already installed
#   4. Asks where to store profiles (or uses the default)
#   5. Walks you through creating your first profiles
#   6. Shows a summary and next steps
#
# Usage:
#   bash setup.sh
# =============================================================================

set -euo pipefail

# ── colors (for pretty terminal output) ──────────────────────────────────────

# Only use colors if the terminal supports them.
if [ -t 1 ]; then
  BOLD="\033[1m"
  GREEN="\033[32m"
  YELLOW="\033[33m"
  BLUE="\033[34m"
  RED="\033[31m"
  CYAN="\033[36m"
  DIM="\033[2m"
  RESET="\033[0m"
else
  BOLD="" GREEN="" YELLOW="" BLUE="" RED="" CYAN="" DIM="" RESET=""
fi

# ── helper functions ─────────────────────────────────────────────────────────

# Print a section header.
section() {
  echo ""
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "${BOLD}  $1${RESET}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo ""
}

# Print a success message.
ok() {
  echo -e "  ${GREEN}✓${RESET} $1"
}

# Print a warning message.
warn() {
  echo -e "  ${YELLOW}!${RESET} $1"
}

# Print an error message.
fail() {
  echo -e "  ${RED}✗${RESET} $1"
}

# Print an info message.
info() {
  echo -e "  ${DIM}$1${RESET}"
}

# Ask a question with a default value. Returns the answer.
# Usage: answer=$(ask "Question?" "default_value")
ask() {
  local prompt=$1
  local default=$2
  local answer

  echo -en "  ${CYAN}?${RESET} ${prompt} "
  if [ -n "$default" ]; then
    echo -en "${DIM}[$default]${RESET} "
  fi
  read -r answer
  echo "${answer:-$default}"
}

# Ask a yes/no question. Returns 0 for yes, 1 for no.
# Usage: if ask_yn "Continue?" "y"; then ...
ask_yn() {
  local prompt=$1
  local default=${2:-n}
  local answer

  if [ "$default" = "y" ]; then
    echo -en "  ${CYAN}?${RESET} ${prompt} ${DIM}[Y/n]${RESET} "
  else
    echo -en "  ${CYAN}?${RESET} ${prompt} ${DIM}[y/N]${RESET} "
  fi
  read -r answer
  answer="${answer:-$default}"
  [[ "$answer" =~ ^[Yy]$ ]]
}

# ── find the multi-codex script ──────────────────────────────────────────────

# Figure out where this setup script is located (multi-codex should be next to it).
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MULTI_CODEX="$SCRIPT_DIR/multi-codex"

# =============================================================================
# STEP 1: WELCOME
# =============================================================================

clear 2>/dev/null || true

echo ""
echo -e "${BOLD}${BLUE}"
echo "  ╔══════════════════════════════════════════════════════╗"
echo "  ║                                                      ║"
echo "  ║             🚀  Multi-Codex Setup Wizard             ║"
echo "  ║                                                      ║"
echo "  ╚══════════════════════════════════════════════════════╝"
echo -e "${RESET}"
echo ""
echo "  Welcome! This wizard will help you set up Multi-Codex."
echo ""
echo "  Multi-Codex lets you run multiple Codex CLI profiles"
echo "  at the same time — each with its own account, config,"
echo "  and sessions. Think of it like browser profiles but"
echo "  for Codex."
echo ""
echo -e "  ${DIM}Press Enter to accept the default for any question.${RESET}"
echo -e "  ${DIM}Press Ctrl+C at any time to cancel.${RESET}"

# =============================================================================
# STEP 2: CHECK PREREQUISITES
# =============================================================================

section "Step 1/4 — Checking Prerequisites"

# Check the platform.
PLATFORM="$(uname -s)"
case "$PLATFORM" in
  Darwin)
    ok "Platform: macOS"
    # Detect chip type.
    CHIP="$(uname -m)"
    if [ "$CHIP" = "arm64" ]; then
      info "Apple Silicon (M-series chip)"
    else
      info "Intel chip"
    fi
    ;;
  Linux)
    ok "Platform: Linux"
    ;;
  *)
    fail "Unsupported platform: $PLATFORM"
    echo ""
    echo "  This setup wizard is for macOS and Linux."
    echo "  Windows users: please run setup.ps1 instead."
    exit 1
    ;;
esac

# Check for Node.js (required by Codex CLI).
if command -v node &>/dev/null; then
  NODE_VER="$(node --version 2>/dev/null || echo "unknown")"
  ok "Node.js: $NODE_VER"
else
  fail "Node.js: NOT FOUND"
  echo ""
  echo "  Codex CLI requires Node.js 22 or later."
  echo "  Install it from: https://nodejs.org/"
  echo ""
  if ! ask_yn "Continue anyway?" "n"; then
    echo "  Setup cancelled. Install Node.js first, then re-run this setup."
    exit 1
  fi
fi

# Check for Codex CLI.
CODEX_PATH=""
if command -v codex &>/dev/null; then
  CODEX_PATH="$(command -v codex)"
  ok "Codex CLI: $CODEX_PATH"
elif [ -d "/Applications/Codex.app" ]; then
  CODEX_PATH="/Applications/Codex.app"
  ok "Codex app: $CODEX_PATH"
elif [ -d "$HOME/Applications/Codex.app" ]; then
  CODEX_PATH="$HOME/Applications/Codex.app"
  ok "Codex app: $CODEX_PATH"
else
  warn "Codex CLI: NOT FOUND"
  echo ""
  echo "  You can install Codex CLI with:"
  echo "    npm install -g @openai/codex"
  echo ""
  if ask_yn "Install Codex CLI now?" "y"; then
    echo ""
    echo "  Installing Codex CLI..."
    if npm install -g @openai/codex 2>/dev/null; then
      ok "Codex CLI installed!"
      CODEX_PATH="$(command -v codex 2>/dev/null || echo "")"
    else
      warn "Could not install automatically. You can install it manually later."
    fi
  else
    warn "Skipping Codex CLI install. You'll need to install it before using profiles."
  fi
fi

# Check for multi-codex itself.
if [ -f "$MULTI_CODEX" ] && [ -x "$MULTI_CODEX" ]; then
  ok "multi-codex script: $MULTI_CODEX"
elif command -v multi-codex &>/dev/null; then
  MULTI_CODEX="$(command -v multi-codex)"
  ok "multi-codex: $MULTI_CODEX (installed globally)"
else
  fail "multi-codex script not found at $MULTI_CODEX"
  echo ""
  echo "  Make sure the 'multi-codex' script is in the same folder as this setup wizard."
  exit 1
fi

# =============================================================================
# STEP 3: CONFIGURE PROFILE STORAGE
# =============================================================================

section "Step 2/4 — Profile Storage Location"

DEFAULT_BASE="$HOME/CodexProfiles"

echo "  Where should Multi-Codex store profiles?"
echo "  Each profile is just a folder with Codex configs inside."
echo ""
PROFILES_DIR=$(ask "Profile storage directory:" "$DEFAULT_BASE")

# Expand ~ to HOME if used.
PROFILES_DIR="${PROFILES_DIR/#\~/$HOME}"

ok "Profiles will be stored at: $PROFILES_DIR"

# =============================================================================
# STEP 4: CREATE PROFILES
# =============================================================================

section "Step 3/4 — Create Your Profiles"

echo "  Let's create your first profiles. You can always create"
echo "  more later with: multi-codex new <name>"
echo ""

NUM_PROFILES=$(ask "How many profiles do you want to create?" "2")

# Validate that the user entered a number.
if ! [[ "$NUM_PROFILES" =~ ^[0-9]+$ ]] || [ "$NUM_PROFILES" -lt 1 ]; then
  warn "Invalid number. Creating 2 profiles."
  NUM_PROFILES=2
fi

# Cap at a reasonable number.
if [ "$NUM_PROFILES" -gt 10 ]; then
  warn "That's a lot of profiles! Capping at 10."
  NUM_PROFILES=10
fi

# Suggest default names.
DEFAULTS=("work" "personal" "client" "test" "dev" "staging" "project-a" "project-b" "project-c" "project-d")
CREATED_PROFILES=()

echo ""
for i in $(seq 1 "$NUM_PROFILES"); do
  DEFAULT_NAME="${DEFAULTS[$((i-1))]}"
  PROFILE_NAME=$(ask "Name for profile #$i:" "$DEFAULT_NAME")

  # Validate the name.
  if ! [[ "$PROFILE_NAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*$ ]]; then
    warn "Invalid name '$PROFILE_NAME'. Using '$DEFAULT_NAME' instead."
    PROFILE_NAME="$DEFAULT_NAME"
  fi

  # Ask if this should be a shared profile.
  SHARED_FLAG=""
  if ask_yn "Make '$PROFILE_NAME' a shared profile? (shares config, isolates auth)" "n"; then
    SHARED_FLAG="--shared"
  fi

  # Create the profile using multi-codex.
  echo ""
  echo "  Creating profile '$PROFILE_NAME'..."
  if MULTICODEX_HOME="$PROFILES_DIR" "$MULTI_CODEX" new "$PROFILE_NAME" $SHARED_FLAG 2>/dev/null; then
    ok "Created profile '$PROFILE_NAME'"
    CREATED_PROFILES+=("$PROFILE_NAME")
  else
    warn "Could not create profile '$PROFILE_NAME' (might already exist)"
  fi
  echo ""
done

# =============================================================================
# STEP 5: SUMMARY
# =============================================================================

section "Step 4/4 — Setup Complete!"

echo -e "  ${GREEN}${BOLD}Everything is set up. Here's what was created:${RESET}"
echo ""

# Show created profiles.
if [ ${#CREATED_PROFILES[@]} -gt 0 ]; then
  echo "  Profiles:"
  for p in "${CREATED_PROFILES[@]}"; do
    echo -e "    ${GREEN}●${RESET}  $p  →  $PROFILES_DIR/$p"
  done
else
  echo "  No profiles were created. Create one with:"
  echo "    multi-codex new <name>"
fi

echo ""
echo -e "  ${BOLD}Quick Reference:${RESET}"
echo ""
echo "  Launch a profile:"
echo -e "    ${CYAN}multi-codex <name>${RESET}              e.g. multi-codex work"
echo ""
echo "  Create a new profile:"
echo -e "    ${CYAN}multi-codex new <name>${RESET}          e.g. multi-codex new client-x"
echo ""
echo "  List all profiles:"
echo -e "    ${CYAN}multi-codex list${RESET}"
echo ""
echo "  Check your setup:"
echo -e "    ${CYAN}multi-codex doctor${RESET}"
echo ""
echo "  See all commands:"
echo -e "    ${CYAN}multi-codex help${RESET}"
echo ""

# If profiles dir is custom, remind user to set the env var.
if [ "$PROFILES_DIR" != "$DEFAULT_BASE" ]; then
  echo -e "  ${YELLOW}Important:${RESET} You chose a custom storage location."
  echo "  Add this to your shell profile (~/.zshrc or ~/.bashrc):"
  echo ""
  echo "    export MULTICODEX_HOME=\"$PROFILES_DIR\""
  echo ""
fi

echo -e "  ${DIM}Each profile gets its own auth, so you'll need to log in"
echo -e "  to each profile the first time you launch it.${RESET}"
echo ""
echo -e "  ${BOLD}Happy coding! 🎉${RESET}"
echo ""
