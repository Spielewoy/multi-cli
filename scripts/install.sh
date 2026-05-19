#!/usr/bin/env bash
# install.sh -- Install multi-cli for macOS/Linux
set -euo pipefail

REPO_URL="${MULTICLI_REPO:-https://github.com/<owner>/<repo>}"
INSTALL_DIR="${MULTICLI_INSTALL_DIR:-$HOME/.local/share/multi-cli}"
BIN_LINK="${MULTICLI_BIN_LINK:-$HOME/.local/bin/multi-cli}"

usage() {
  cat <<EOF
multi-cli installer

USAGE
  ./install.sh [--local]

OPTIONS
  --local    Install from the current directory instead of cloning from git.

ENVIRONMENT
  MULTICLI_REPO          Git clone URL (default: $REPO_URL)
  MULTICLI_INSTALL_DIR   Install directory (default: $INSTALL_DIR)
  MULTICLI_BIN_LINK      Symlink location (default: $BIN_LINK)

EOF
  exit 0
}

local_install=false
for arg in "$@"; do
  case "$arg" in
    --local) local_install=true ;;
    --help|-h) usage ;;
  esac
done

echo "multi-cli installer"
echo ""

if [ "$local_install" = true ]; then
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  INSTALL_DIR="$(dirname "$SCRIPT_DIR")"
  echo "Installing from local directory: $INSTALL_DIR"
else
  if [[ "$REPO_URL" == *"<owner>"* ]]; then
    echo "Error: MULTICLI_REPO is not set. Set it to the git clone URL." >&2
    echo "  export MULTICLI_REPO=https://github.com/youruser/multi-cli" >&2
    exit 1
  fi
  echo "Cloning from $REPO_URL ..."
  if [ -d "$INSTALL_DIR" ]; then
    echo "Updating existing installation at $INSTALL_DIR"
    git -C "$INSTALL_DIR" pull --ff-only
  else
    mkdir -p "$(dirname "$INSTALL_DIR")"
    git clone "$REPO_URL" "$INSTALL_DIR"
  fi
fi

chmod +x "$INSTALL_DIR/multi-cli"

mkdir -p "$(dirname "$BIN_LINK")"
ln -sf "$INSTALL_DIR/multi-cli" "$BIN_LINK"

echo ""
echo "Installed multi-cli to $INSTALL_DIR"
echo "Symlinked to $BIN_LINK"

if ! command -v multi-cli >/dev/null 2>&1; then
  echo ""
  echo "NOTE: $(dirname "$BIN_LINK") is not in your PATH."
  echo "Add this to your shell profile (~/.bashrc, ~/.zshrc):"
  echo ""
  echo "  export PATH=\"$(dirname "$BIN_LINK"):\$PATH\""
fi

if ! command -v jq >/dev/null 2>&1; then
  echo ""
  echo "WARNING: jq is required but not installed."
  echo "  macOS:  brew install jq"
  echo "  Linux:  apt install jq / dnf install jq"
fi

echo ""
echo "Run 'multi-cli doctor' to verify your setup."
