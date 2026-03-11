#!/usr/bin/env bash
set -euo pipefail

ROOT="$PWD/NixOS/nixos-build/nixorcist"
LOCK_FILE="$(mktemp)"
MODULES_DIR="$(mktemp -d)"
TEST_INDEX="$(mktemp)"
FZF_CALL_FILE="$(mktemp)"
printf '0\n' > "$FZF_CALL_FILE"

cleanup() {
  rm -f "$LOCK_FILE" "$TEST_INDEX"
  rm -f "$FZF_CALL_FILE"
  rm -rf "$MODULES_DIR"
}
trap cleanup EXIT

source "$ROOT/lib/cli.sh"
source "$ROOT/lib/utils.sh"
source "$ROOT/lib/lock.sh"

# Quiet noisy UI during tests
show_logo(){ :; }
show_section_header(){ :; }
show_section(){ :; }
show_divider(){ :; }
show_warning(){ :; }
show_error(){ :; }
show_info(){ :; }
show_success(){ :; }
show_item(){ :; }
nixorcist_trace(){ :; }
nixorcist_trace_selection(){ :; }

cat > "$TEST_INDEX" <<IDX
swaynotificationcenter.swaync-client|desc
swaynotificationcenter.swaync-daemon|desc
swaynotificationcenter|desc
eclipses|desc
eclipses.eclipse-java|desc
eclipses.eclipse-cpp|desc
eclipses.eclipse-sdk|desc
IDX

get_index_file() { echo "$TEST_INDEX"; }
ensure_index() { return 0; }
get_pkg_preview_text() { echo "preview for $1"; }

# Mock package graph for attrset resolution tests
get_pkg_type() {
  case "$1" in
    eclipses|eclipses.tools) echo attrset ;;
    eclipses.eclipse-java|eclipses.eclipse-cpp|eclipses.eclipse-sdk|eclipses.tools.helper) echo package ;;
    *) echo unknown ;;
  esac
}
index_has_children() {
  [[ "$1" == "eclipses" || "$1" == "eclipses.tools" ]]
}
list_attrset_children() {
  case "$1" in
    eclipses) printf '%s\n' eclipse-java eclipse-cpp eclipse-sdk tools ;;
    eclipses.tools) printf '%s\n' helper ;;
    *) return 0 ;;
  esac
}
resolve_entry_to_packages() {
  local entry="$1"
  local -n out_ref=$2
  out_ref=()
  case "$entry" in
    eclipses)
      out_ref=(eclipses.eclipse-java eclipses.eclipse-cpp eclipses.eclipse-sdk)
      return 0
      ;;
    eclipses.tools)
      out_ref=(eclipses.tools.helper)
      return 0
      ;;
    eclipses.eclipse-java|eclipses.eclipse-cpp|eclipses.eclipse-sdk|eclipses.tools.helper)
      out_ref=("$entry")
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# fzf mock dispatcher
fzf() {
  # Consume full piped input to emulate real fzf and avoid SIGPIPE with pipefail.
  if [[ ! -t 0 ]]; then
    cat >/dev/null || true
  fi
  local fzf_call
  fzf_call="$(<"$FZF_CALL_FILE")"
  fzf_call=$((fzf_call + 1))
  printf '%s\n' "$fzf_call" > "$FZF_CALL_FILE"
  case "$fzf_call" in
    # menu A: choose owner-search row with query swaync
    1)
      printf 'enter\nswaync\n__OWNER_SEARCH__\tOWNER SEARCH FROM CURRENT QUERY\n'
      ;;
    # menu B: choose owner candidate
    2)
      printf 'enter\nswaynotificationcenter\n'
      ;;
    # approval menu: explicit yes
    3)
      printf 'enter\nYes - add owner package\n'
      ;;
    # menu A again with owner highlighted and selected
    4)
      printf 'enter\n\nswaynotificationcenter\tswaynotificationcenter <=== OWNER OF THE SEARCHED PACKAGE swaync\n'
      ;;
    # attrset manual select: choose tools attrset only
    5)
      printf 'tools\n'
      ;;
    *)
      return 1
      ;;
  esac
}

printf 'TEST 1: true two-menu owner flow (swaync)\n'
start=$SECONDS
owner_out="$(transaction_pick_from_index)"
dur=$((SECONDS-start))
printf 'result=%s\n' "$owner_out"
printf 'duration=%ss\n' "$dur"
[[ "$owner_out" == "swaynotificationcenter" ]]

printf '\nTEST 2: attrset decision menu W (eclipses)\n'
declare -A tmap=()
start=$SECONDS
transaction_resolve_token_for_query "eclipses" tmap <<<"w"
dur=$((SECONDS-start))
printf 'duration=%ss count=%s\n' "$dur" "${#tmap[@]}"
[[ ${#tmap[@]} -eq 3 ]]
[[ -n "${tmap[eclipses.eclipse-java]:-}" ]]

printf '\nTEST 3: attrset decision menu default skip (empty)\n'
declare -A tmap_skip=()
start=$SECONDS
if transaction_resolve_token_for_query "eclipses" tmap_skip <<<""; then
  :
fi
dur=$((SECONDS-start))
printf 'duration=%ss count=%s\n' "$dur" "${#tmap_skip[@]}"
[[ ${#tmap_skip[@]} -eq 0 ]]

printf '\nTEST 4: attrset manual recursive branch (M -> tools -> A) and nameref safety\n'
# Use manual M first prompt and then recursive A for nested attrset prompt.
declare -A tmap_m=()
# feed two prompts: m for first, a for nested attrset
after_err="$( { transaction_resolve_token_for_query "eclipses" tmap_m <<< $'m\na\n'; } 2>&1 )"
printf 'stderr=%s\n' "$after_err"
printf 'count=%s\n' "${#tmap_m[@]}"
# must not show circular reference warnings
if printf '%s' "$after_err" | rg -q 'circular name reference'; then
  echo 'Found circular name reference warning' >&2
  exit 1
fi

printf '\nALL TESTS PASSED\n'
