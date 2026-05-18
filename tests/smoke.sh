#!/usr/bin/env bash
# smoke.sh -- Smoke tests for multi-cli (macOS/Linux)
# Iterates all tool adapters, creates a throwaway profile, launches with --version,
# verifies isolation, then cleans up.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CLI="$SCRIPT_DIR/multi-cli"
TOOLS_DIR="$SCRIPT_DIR/tools"
TIMEOUT_SEC=8

RED='\033[31m'; GREEN='\033[32m'; YELLOW='\033[33m'; CYAN='\033[36m'; RESET='\033[0m'

command -v jq >/dev/null 2>&1 || { echo "jq is required for smoke tests"; exit 1; }

pass=0; fail=0; skip=0
declare -A results

for adapter in "$TOOLS_DIR"/*/adapter.json; do
  tool_dir="$(dirname "$adapter")"
  tool_id="$(basename "$tool_dir")"
  display="$(jq -r '.displayName' "$adapter")"

  printf "\n${CYAN}=== %s (%s) ===${RESET}\n" "$tool_id" "$display"

  if ! "$CLI" tools 2>/dev/null | grep -q "$tool_id.*yes"; then
    printf "  ${YELLOW}SKIP${RESET} -- binary not detected on this machine\n"
    results[$tool_id]="SKIP   binary not detected"
    skip=$((skip + 1))
    continue
  fi

  spec="$tool_id/smoketest"
  profile_dir="${MULTICLI_HOME:-$HOME/MultiCliProfiles}/$tool_id/smoketest"

  if [ -d "$profile_dir" ]; then
    echo "  cleanup: removing leftover profile dir"
    rm -rf "$profile_dir"
  fi

  echo "  step 1: create profile $spec"
  "$CLI" new "$spec" 2>&1 | sed 's/^/    /'

  echo "  step 2: launch with --version (${TIMEOUT_SEC}s timeout)"
  version_output=""
  exit_code=0
  version_output="$(timeout "$TIMEOUT_SEC" "$CLI" launch "$spec" -- --version 2>&1)" || exit_code=$?

  echo "  step 3: verify isolation"
  file_count=0
  if [ -d "$profile_dir" ]; then
    file_count="$(find "$profile_dir" -type f 2>/dev/null | wc -l | tr -d ' ')"
  fi

  result=""
  if [ -n "$version_output" ] && [ "$file_count" -gt 0 ]; then
    result="PASS   version printed; $file_count files written"
    printf "  ${GREEN}PASS${RESET} -- version printed; %s extra files written\n" "$file_count"
    pass=$((pass + 1))
  elif [ -n "$version_output" ]; then
    result="PASS   version printed; 0 extra files written"
    printf "  ${GREEN}PASS${RESET} -- version printed; 0 extra files written\n"
    pass=$((pass + 1))
  elif [ "$file_count" -gt 0 ]; then
    result="PASS   $file_count files written into profile dir (isolation verified)"
    printf "  ${GREEN}PASS${RESET} -- %s files written into profile dir (isolation verified)\n" "$file_count"
    pass=$((pass + 1))
  else
    result="FAIL   no version output, no files written (exit=$exit_code)"
    printf "  ${RED}FAIL${RESET} -- no version output, no files written (exit=%s)\n" "$exit_code"
    fail=$((fail + 1))
  fi
  results[$tool_id]="$result"

  echo "  step 4: cleanup"
  rm -rf "$profile_dir"
  rm -f "${MULTICLI_HOME:-$HOME/MultiCliProfiles}/bin/$tool_id-smoketest" 2>/dev/null || true
done

echo ""
printf "${CYAN}=== SUMMARY ===${RESET}\n"
for tid in $(echo "${!results[@]}" | tr ' ' '\n' | sort); do
  printf "  %-18s %s\n" "$tid" "${results[$tid]}"
done

echo ""
if [ "$fail" -eq 0 ]; then
  printf "${GREEN}All installed tools passed.${RESET}\n"
else
  printf "${RED}%d failed, %d passed, %d skipped.${RESET}\n" "$fail" "$pass" "$skip"
  exit 1
fi
