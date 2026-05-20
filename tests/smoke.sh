#!/usr/bin/env bash
# smoke.sh — Real-launch smoke tests for multi-cli adapters
#
# Runs each adapter that can be detected on this machine against a
# throwaway profile, verifies isolation, then cleans up.
#
# Usage:
#   ./tests/smoke.sh                # all detected tools
#   ./tests/smoke.sh agy antigravity # specific tools
#   KEEP_PROFILES=1 ./tests/smoke.sh # don't clean up (debug)

set -euo pipefail
shopt -s nullglob

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TOOLS_DIR="$PROJECT_DIR"
BASE="${MULTICLI_HOME:-$HOME/MultiCliProfiles}"
TIMEOUT_SEC=8
SMOKE_PROFILE_NAME="smoketest"

export MULTICLI_HOME="$BASE"

green=(); red=(); yellow=()

platform() {
  local raw="${MULTICLI_PLATFORM:-$(uname -s)}"
  raw="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]')"
  case "$raw" in
    darwin|macos|mac|osx) printf 'darwin\n' ;;
    linux)                printf 'linux\n' ;;
    mingw*|msys*|cygwin*) printf 'windows\n' ;;
    *)                    echo "unsupported platform '$raw'" >&2; exit 1 ;;
  esac
}

PLAT="$(platform)"

echo "== multi-cli smoke tests =="
echo "Tools dir: $TOOLS_DIR"
echo "Timeout:   ${TIMEOUT_SEC}s"
echo ""

tools=()
for d in "$TOOLS_DIR"/*/; do
  [ -f "$d/adapter.json" ] && tools+=("$(basename "$d")")
done

if [ "${1:-}" != "" ]; then tools=("$@"); fi

[ ${#tools[@]} -eq 0 ] && { echo "No adapters found."; exit 0; }

failed_any=false

for tool in "${tools[@]}"; do
  apath="$TOOLS_DIR/$tool/adapter.json"
  [ -f "$apath" ] || { echo "[SKIP] $tool — no adapter.json"; yellow+=("$tool"); continue; }

  # determine platform key
  case "$PLAT" in
    darwin)  pkey="macos" ;;
    linux)   pkey="linux" ;;
    windows) pkey="windows" ;;
  esac

  strategy="$(jq -r '.isolation.strategy' "$apath" 2>/dev/null || true)"
  version_cmd="$(jq -r '.versionCommand // ["--version"] | join(" ")' "$apath" 2>/dev/null || echo '--version')"
  [ -z "$version_cmd" ] && version_cmd="--version"

  pdir="$BASE/$tool/$SMOKE_PROFILE_NAME"

  # binary discovery
  binary=""
  candidates="$(jq -r ".binary.$pkey // [] | .[]" "$apath" 2>/dev/null || true)"
  while IFS= read -r c; do
    [ -z "$c" ] && continue
    resolved="${c//\$HOME/$HOME}"
    resolved="${resolved//\~/$HOME}"
    [ -x "$resolved" ] && { binary="$resolved"; break; }
    command -v "$resolved" >/dev/null 2>&1 && { binary="$resolved"; break; }
  done <<< "$candidates"

  if [ -z "$binary" ]; then
    echo "[SKIP] $tool — binary not detected"
    yellow+=("$tool")
    continue
  fi

  echo -n "[TEST] $tool ($strategy) ... "

  # cleanup leftover
  rm -rf "$pdir" 2>/dev/null || true
  mkdir -p "$(dirname "$pdir")"

  # create profile
  case "$strategy" in
    redirectHome)
      mkdir -p "$pdir"
      hdir="$pdir/_home"
      mkdir -p "$hdir"
      while IFS= read -r entry; do
        [ -z "$entry" ] && continue
        src="$HOME/$entry"
        dst="$hdir/$entry"
        [ -e "$src" ] && [ ! -e "$dst" ] && ln -s "$src" "$dst" 2>/dev/null || true
      done < <(jq -r '.isolation.shareFromRealHome // [] | .[]' "$apath" 2>/dev/null || true)
      ;;
    userDataDir)
      mkdir -p "$pdir/extensions"
      ;;
    *)
      mkdir -p "$pdir"
      ;;
  esac

  # record pre-launch state
  pre_ts=$(find "$pdir" -printf '%p %T@\n' 2>/dev/null || true)

  # launch
  printed_version=false
  output=""

  case "$strategy" in
    redirectHome)
      hdir="$pdir/_home"
      output="$(HOME="$hdir" timeout "$TIMEOUT_SEC" "$binary" $version_cmd 2>&1)" || true
      ;;
    userDataDir)
      output="$(timeout "$TIMEOUT_SEC" "$binary" --user-data-dir "$pdir" --extensions-dir "$pdir/extensions" $version_cmd 2>&1)" || true
      ;;
    env)
      env_vars=()
      while IFS= read -r key; do
        [ -z "$key" ] && continue
        val="$(jq -r ".isolation.env[\"$key\"]" "$apath" 2>/dev/null)"
        val="${val//\{profileDir\}/$pdir}"
        env_vars+=("$key=$val")
      done < <(jq -r '.isolation.env // {} | keys[]' "$apath" 2>/dev/null || true)
      if [ ${#env_vars[@]} -gt 0 ]; then
        output="$(env "${env_vars[@]}" timeout "$TIMEOUT_SEC" "$binary" $version_cmd 2>&1)" || true
      else
        output="$(timeout "$TIMEOUT_SEC" "$binary" $version_cmd 2>&1)" || true
      fi
      ;;
    *)
      output="$(timeout "$TIMEOUT_SEC" "$binary" $version_cmd 2>&1)" || true
      ;;
  esac

  if echo "$output" | grep -qE '[0-9]+\.[0-9]+'; then
    printed_version=true
  fi

  # check if files were touched
  touched=false
  post_ts=$(find "$pdir" -newer "$pdir" -printf '%p\n' 2>/dev/null | head -1)
  [ -n "$post_ts" ] && touched=true

  if [ "$printed_version" = true ] || [ "$touched" = true ]; then
    echo "PASS"
    green+=("$tool")
  else
    echo "FAIL (no isolation evidence)"
    red+=("$tool")
    failed_any=true
  fi

  [ "${KEEP_PROFILES:-}" != "1" ] && rm -rf "$pdir" 2>/dev/null || true

  echo ""
  sleep 1
done

# summary
echo "===== Results ====="
max_len=0
for t in "${tools[@]}"; do [ ${#t} -gt $max_len ] && max_len=${#t}; done

for t in "${tools[@]}"; do
  if [[ " ${green[*]} " =~ " $t " ]]; then mark="PASS"
  elif [[ " ${red[*]} " =~ " $t " ]]; then mark="FAIL"
  else mark="SKIP"; fi
  printf "  %-*s  %s\n" $((max_len + 2)) "$t" "$mark"
done

echo ""
echo "PASS: ${#green[@]}  FAIL: ${#red[@]}  SKIP: ${#yellow[@]}"
[ ${#red[@]} -gt 0 ] && echo "FAILURES: ${red[*]}"

[ "$failed_any" = true ] && exit 1
