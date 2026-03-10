set -euo pipefail

NIXORCIST_MARKER='#$nixorcist$#'
BUILT_MARKER='#$built$#'

: "${LOCK_FILE:?LOCK_FILE not set}"
: "${MODULES_DIR:?MODULES_DIR not set}"

read_lock_entries() {
  grep -v -F "$BUILT_MARKER" "$LOCK_FILE" 2>/dev/null \
    | sed '/^[[:space:]]*$/d' | sort -u
}

write_lock_entries() {
  local -n entries_ref=$1
  printf '%s\n' "${entries_ref[@]}" | sed '/^[[:space:]]*$/d' | sort -u > "$LOCK_FILE"
  echo "$BUILT_MARKER" >> "$LOCK_FILE"
}

scan_managed_modules() {
  shopt -s nullglob
  for f in "$MODULES_DIR"/*.nix; do
    if grep -qF "$NIXORCIST_MARKER" "$f" 2>/dev/null; then
      grep -E '^[[:space:]]*#[[:space:]]*NIXORCIST-ATTRPATH:' "$f" \
        | head -1 \
        | sed 's/^[[:space:]]*#[[:space:]]*NIXORCIST-ATTRPATH:[[:space:]]*//'
    fi
  done | sort -u
  shopt -u nullglob
}

transaction_init() {
  declare -gA TX_ADD=()
  declare -gA TX_REMOVE=()
  declare -gA TX_LOCK=()
  TX_FILE="$(mktemp /tmp/nixorcist-transaction.XXXXXX)"

  local pkg
  while IFS= read -r pkg; do
    [[ -z "$pkg" ]] && continue
    TX_LOCK["$pkg"]=1
  done < <(read_lock_entries)
}

transaction_cleanup() {
  [[ -n "${TX_FILE:-}" && -f "$TX_FILE" ]] && rm -f "$TX_FILE"
}

transaction_expand_and_stage() {
  local mode="$1"
  local entry="$2"
  local resolved=()
  local pkg

  entry="$(sanitize_token "$entry")"
  if ! is_valid_token "$entry"; then
    show_error "Invalid token: $entry"
    return 1
  fi

  if ! resolve_entry_to_packages "$entry" resolved; then
    show_error "Skipping empty/invalid: $entry"
    return 1
  fi

  for pkg in "${resolved[@]}"; do
    if [[ "$mode" == "add" ]]; then
      TX_ADD["$pkg"]=1
      unset TX_REMOVE["$pkg"] 2>/dev/null || true
    else
      TX_REMOVE["$pkg"]=1
      unset TX_ADD["$pkg"] 2>/dev/null || true
    fi
  done

  if [[ "$mode" == "add" ]]; then
    show_item "+" "Staged: $entry [${#resolved[@]} package(s)]"
  else
    show_item "-" "Staged: $entry [${#resolved[@]} package(s)]"
  fi
}

transaction_pick_from_index() {
  ensure_index
  awk -F'|' '{print $1}' "$(get_index_file)" \
    | sed '/^[[:space:]]*$/d' | sort -u \
    | fzf --multi \
      --prompt="SELECT> " \
      --header="TAB mark | ENTER confirm" \
      --preview 'desc=$(grep "^{}|" "'"$(get_index_file)"'" | cut -d"|" -f2-); [[ -z "$desc" ]] && desc="No description"; printf "%s\n\nType: %s\n" "$desc" "$(get_pkg_description {})"' \
      --preview-window=down:6:wrap
}

transaction_pick_for_remove() {
  {
    printf '%s\n' "${!TX_LOCK[@]}"
    printf '%s\n' "${!TX_ADD[@]}"
  } | sed '/^[[:space:]]*$/d' | sort -u \
    | fzf --multi \
      --prompt="REMOVE> " \
      --header="TAB mark | ENTER confirm" \
      --preview 'get_pkg_description {}' \
      --preview-window=down:4:wrap
}

transaction_unstage_menu() {
  local mode="$1"
  local selected

  if [[ "$mode" == "add" ]]; then
    [[ ${#TX_ADD[@]} -eq 0 ]] && { show_info "No staged installs."; return; }
    selected=$(printf '%s\n' "${!TX_ADD[@]}" | sort -u | fzf --multi --prompt="UNSTAGE> ")
    [[ -z "$selected" ]] && return
    while IFS= read -r pkg; do
      [[ -z "$pkg" ]] && continue
      unset TX_ADD["$pkg"]
    done <<< "$selected"
  else
    [[ ${#TX_REMOVE[@]} -eq 0 ]] && { show_info "No staged removals."; return; }
    selected=$(printf '%s\n' "${!TX_REMOVE[@]}" | sort -u | fzf --multi --prompt="UNSTAGE> ")
    [[ -z "$selected" ]] && return
    while IFS= read -r pkg; do
      [[ -z "$pkg" ]] && continue
      unset TX_REMOVE["$pkg"]
    done <<< "$selected"
  fi
}

transaction_preview() {
  echo
  printf '  Install: %d packages\n' "${#TX_ADD[@]}"
  [[ ${#TX_ADD[@]} -gt 0 ]] && printf '    + %s\n' "${!TX_ADD[@]}" | sort -u | head -10 || echo "    (none)"
  echo
  printf '  Remove: %d packages\n' "${#TX_REMOVE[@]}"
  [[ ${#TX_REMOVE[@]} -gt 0 ]] && printf '    - %s\n' "${!TX_REMOVE[@]}" | sort -u | head -10 || echo "    (none)"
  echo
}

transaction_write_temp() {
  {
    echo "# ADD"
    printf '%s\n' "${!TX_ADD[@]}" | sed '/^[[:space:]]*$/d' | sort -u
    echo "# REMOVE"
    printf '%s\n' "${!TX_REMOVE[@]}" | sed '/^[[:space:]]*$/d' | sort -u
  } > "$TX_FILE"
}

transaction_apply() {
  local -A next=()
  local pkg

  for pkg in "${!TX_LOCK[@]}"; do
    next["$pkg"]=1
  done

  for pkg in "${!TX_ADD[@]}"; do
    next["$pkg"]=1
  done

  for pkg in "${!TX_REMOVE[@]}"; do
    unset next["$pkg"]
  done

  local final=()
  for pkg in "${!next[@]}"; do
    final+=("$pkg")
  done

  write_lock_entries final
  transaction_write_temp
  show_success "Lock updated"
}

transaction_menu_loop() {
  local action selected item

  while true; do
    echo
    echo "  1) Stage +  2) Unstage +  3) Stage -  4) Unstage -"
    echo "  5) Preview  6) Apply      7) Cancel"
    read -r -p "  Choose [1-7]: " action

    case "$action" in
      1)
        selected="$(transaction_pick_from_index || true)"
        [[ -z "$selected" ]] && continue
        while IFS= read -r item; do
          [[ -z "$item" ]] && continue
          transaction_expand_and_stage add "$item" || true
        done <<< "$selected"
        ;;
      2)
        transaction_unstage_menu add
        ;;
      3)
        selected="$(transaction_pick_for_remove || true)"
        [[ -z "$selected" ]] && continue
        while IFS= read -r item; do
          [[ -z "$item" ]] && continue
          transaction_expand_and_stage remove "$item" || true
        done <<< "$selected"
        ;;
      4)
        transaction_unstage_menu remove
        ;;
      5)
        transaction_preview
        ;;
      6)
        transaction_apply
        return 0
        ;;
      7)
        show_info "Cancelled"
        return 1
        ;;
      *)
        show_error "Invalid option"
        ;;
    esac
  done
}

run_transaction_cli() {
  transaction_init
  if transaction_menu_loop; then
    transaction_cleanup
    return 0
  fi
  transaction_cleanup
  return 1
}

select_packages() {
  run_transaction_cli
}

add_packages() {
  run_transaction_cli
}

remove_packages() {
  run_transaction_cli
}

handle_missing_package() {
  local missing="$1"
  local suggested=""

  suggested=$(awk -F'|' '{print $1}' "$(get_index_file)" | grep -i "$missing" | head -50 \
    | fzf --prompt="Resolve '$missing' > " --header="Pick replacement or ESC to skip" || true)

  [[ -z "$suggested" ]] && return 1
  transaction_expand_and_stage add "$suggested"
}

import_from_file() {
  local file="$1"
  local normalized token review_answer run_all_answer

  if [[ -z "$file" || ! -f "$file" ]]; then
    show_error "Provide a valid text file"
    return 1
  fi

  ensure_index
  transaction_init

  normalized=$(tr ',\n\t ' '\n\n\n\n' < "$file")
  while IFS= read -r token; do
    token="$(sanitize_token "$token")"
    [[ -z "$token" ]] && continue

    if transaction_expand_and_stage add "$token"; then
      continue
    fi

    handle_missing_package "$token" || show_item "?" "Unresolved: $token"
  done <<< "$normalized"

  show_divider
  read -r -p "  Review transaction? [Y/n]: " review_answer
  case "${review_answer,,}" in
    n)
      transaction_apply
      ;;
    *)
      transaction_menu_loop || { transaction_cleanup; return 1; }
      ;;
  esac

  transaction_cleanup

  echo
  read -r -p "  Run full pipeline? [y/N]: " run_all_answer
  case "${run_all_answer,,}" in
    y)
      generate_modules
      regenerate_hub
      run_rebuild
      ;;
    *)
      show_info "Import complete"
      ;;
  esac
}
