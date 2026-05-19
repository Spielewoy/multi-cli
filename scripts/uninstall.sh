#!/usr/bin/env bash
# uninstall.sh -- Remove multi-cli from macOS/Linux
set -euo pipefail

INSTALL_DIR="${MULTICLI_INSTALL_DIR:-$HOME/.local/share/multi-cli}"
BIN_LINK="${MULTICLI_BIN_LINK:-$HOME/.local/bin/multi-cli}"
PROFILE_DIR="${MULTICLI_HOME:-$HOME/MultiCliProfiles}"

echo "multi-cli uninstaller"
echo ""

if [ -L "$BIN_LINK" ]; then
  rm -f "$BIN_LINK"
  echo "Removed symlink: $BIN_LINK"
fi

if [ -d "$INSTALL_DIR" ] && [ "$INSTALL_DIR" != "$(pwd)" ]; then
  printf "Remove install directory %s? [y/N] " "$INSTALL_DIR"
  read -r confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    rm -rf "$INSTALL_DIR"
    echo "Removed $INSTALL_DIR"
  fi
fi

if [ -d "$PROFILE_DIR" ]; then
  printf "Remove all profiles at %s? [y/N] " "$PROFILE_DIR"
  read -r confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    rm -rf "$PROFILE_DIR"
    echo "Removed $PROFILE_DIR"
  else
    echo "Profiles kept at $PROFILE_DIR"
  fi
fi

echo ""
echo "multi-cli uninstalled."
