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

  # Check if it's an attrset and handle special menu
  local entry_type="$(get_pkg_type "$entry")"
  if [[ "$entry_type" == "attrset" ]]; then
    transaction_handle_attrset "$mode" "$entry"
    return $?
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
  return 0
}

transaction_handle_attrset() {
  local mode="$1"
  local attrset="$2"
  local pkg_count="$(count_attrset_packages "$attrset")"
  local choice resolved=()
  
  show_section "Attrset: $attrset ($pkg_count packages)"
  echo "  This is an attribute set containing multiple packages."
  echo
  echo "  What would you like to do?"
  echo "    [1] Browse  - Select specific packages from this attrset"
  echo "    [2] All     - Add/remove all packages from this attrset"
  echo "    [3] First   - Use the first (closest) package"
  echo "    [4] Skip    - Skip this attrset"
  echo
  read -r -p "  Choose [1-4]: " choice
  
  case "$choice" in
    1)
      # Browse attrset packages with fzf
      local selected
      selected=$(list_attrset_children "$attrset" | sort -u | fzf --multi \
        --prompt="SELECT FROM $attrset > " \
        --header="TAB=multi | ENTER=confirm | ESC=cancel" \
        --preview "get_pkg_description $attrset.{}")
      
      if [[ -n "$selected" ]]; then
        local pkg_name
        while IFS= read -r pkg_name; do
          [[ -z "$pkg_name" ]] && continue
          local full_pkg="$attrset.$pkg_name"
          if [[ "$mode" == "add" ]]; then
            TX_ADD["$full_pkg"]=1
            unset TX_REMOVE["$full_pkg"] 2>/dev/null || true
          else
            TX_REMOVE["$full_pkg"]=1
            unset TX_ADD["$full_pkg"] 2>/dev/null || true
          fi
        done <<< "$selected"
        show_item "✓" "Selected ${#selected}/$(echo "$selected" | wc -l) from $attrset"
        return 0
      else
        show_item "⊘" "Browse cancelled"
        return 1
      fi
      ;;
    2)
      # Select all packages from attrset
      if resolve_entry_to_packages "$attrset" resolved; then
        for pkg in "${resolved[@]}"; do
          if [[ "$mode" == "add" ]]; then
            TX_ADD["$pkg"]=1
            unset TX_REMOVE["$pkg"] 2>/dev/null || true
          else
            TX_REMOVE["$pkg"]=1
            unset TX_ADD["$pkg"] 2>/dev/null || true
          fi
        done
        show_item "✓" "Selected all packages from $attrset (${#resolved[@]})"
        return 0
      else
        show_error "No packages found in $attrset"
        return 1
      fi
      ;;
    3)
      # Get closest (first) package from attrset
      if resolve_entry_to_packages "$attrset" resolved; then
        local closest="${resolved[0]}"
        if [[ "$mode" == "add" ]]; then
          TX_ADD["$closest"]=1
          unset TX_REMOVE["$closest"] 2>/dev/null || true
        else
          TX_REMOVE["$closest"]=1
          unset TX_ADD["$closest"] 2>/dev/null || true
        fi
        show_item "✓" "Selected closest package: $closest"
        return 0
      else
        show_error "No packages found in $attrset"
        return 1
      fi
      ;;
    4)
      show_item "⊘" "Skipped: $attrset"
      return 1
      ;;
    *)
      show_error "Invalid choice"
      return 1
      ;;
  esac
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
    selected=$(printf '%s\n' "${!TX_ADD[@]}" | sort -u | fzf --multi --prompt="UNSTAGE > ")
    [[ -z "$selected" ]] && return
    while IFS= read -r pkg; do
      [[ -z "$pkg" ]] && continue
      unset TX_ADD["$pkg"]
    done <<< "$selected"
  else
    [[ ${#TX_REMOVE[@]} -eq 0 ]] && { show_info "No staged removals."; return; }
    selected=$(printf '%s\n' "${!TX_REMOVE[@]}" | sort -u | fzf --multi --prompt="UNSTAGE > ")
    [[ -z "$selected" ]] && return
    while IFS= read -r pkg; do
      [[ -z "$pkg" ]] && continue
      unset TX_REMOVE["$pkg"]
    done <<< "$selected"
  fi
}

transaction_submenu_install_queue() {
  while true; do
    clear
    show_logo
    show_section_header 'Manage Install Queue'
    
    if [[ ${#TX_ADD[@]} -eq 0 ]]; then
      printf '  (empty)\n'
    else
      printf '  Staged for installation:\n\n'
      printf '%s\n' "${!TX_ADD[@]}" | sort -u | nl | while read -r num pkg; do
        printf '    %2d. %s\n' "$num" "$pkg"
      done | head -20
      
      local total=${#TX_ADD[@]}
      if [[ $total -gt 20 ]]; then
        printf '\n    ... and %d more\n' $((total - 20))
      fi
    fi
    
    echo
    show_menu_item '1' 'Remove from queue    - select packages to unstage'
    show_menu_item '2' 'Clear all            - empty the install queue'
    show_menu_item '0' 'Back'
    echo
    
    printf '  Select an option (0-2): '
    read -r choice
    
    case "$choice" in
      1)
        if [[ ${#TX_ADD[@]} -eq 0 ]]; then
          show_error 'Install queue is empty'
          wait_for_key
        else
          transaction_unstage_menu add
        fi
        ;;
      2)
        if [[ ${#TX_ADD[@]} -eq 0 ]]; then
          show_error 'Install queue is empty'
          wait_for_key
        else
          show_warning 'This will clear all staged installs.'
          show_yes_no_prompt 'Continue?'
          read -r confirm
          
          if [[ "${confirm,,}" == "y" ]]; then
            TX_ADD=()
            show_success 'Install queue cleared'
            sleep 1
          fi
        fi
        ;;
      0) break ;;
      *)
        show_error 'Invalid option.'
        wait_for_key
        ;;
    esac
  done
}

transaction_submenu_remove_queue() {
  while true; do
    clear
    show_logo
    show_section_header 'Manage Remove Queue'
    
    if [[ ${#TX_REMOVE[@]} -eq 0 ]]; then
      printf '  (empty)\n'
    else
      printf '  Staged for removal:\n\n'
      printf '%s\n' "${!TX_REMOVE[@]}" | sort -u | nl | while read -r num pkg; do
        printf '    %2d. %s\n' "$num" "$pkg"
      done | head -20
      
      local total=${#TX_REMOVE[@]}
      if [[ $total -gt 20 ]]; then
        printf '\n    ... and %d more\n' $((total - 20))
      fi
    fi
    
    echo
    show_menu_item '1' 'Remove from queue    - select packages to unstage'
    show_menu_item '2' 'Clear all            - empty the remove queue'
    show_menu_item '0' 'Back'
    echo
    
    printf '  Select an option (0-2): '
    read -r choice
    
    case "$choice" in
      1)
        if [[ ${#TX_REMOVE[@]} -eq 0 ]]; then
          show_error 'Remove queue is empty'
          wait_for_key
        else
          transaction_unstage_menu remove
        fi
        ;;
      2)
        if [[ ${#TX_REMOVE[@]} -eq 0 ]]; then
          show_error 'Remove queue is empty'
          wait_for_key
        else
          show_warning 'This will clear all staged removals.'
          show_yes_no_prompt 'Continue?'
          read -r confirm
          
          if [[ "${confirm,,}" == "y" ]]; then
            TX_REMOVE=()
            show_success 'Remove queue cleared'
            sleep 1
          fi
        fi
        ;;
      0) break ;;
      *)
        show_error 'Invalid option.'
        wait_for_key
        ;;
    esac
  done
}
show_transaction_header() {
  show_section_header 'Transaction Builder'
  printf '  %-45s %s\n' "Queued to Install:" "${#TX_ADD[@]} package(s)"
  printf '  %-45s %s\n' "Queued to Remove:" "${#TX_REMOVE[@]} package(s)"
  echo
  show_divider
  echo
}

transaction_menu_loop_tty() {
  local choice
  local selected item

  while true; do
    clear
    show_logo
    show_transaction_header
    show_status_line "Use numbers and Enter to navigate."
    echo
    show_menu_item '1' 'Add packages        - browse and queue installs'
    show_menu_item '2' 'Remove packages     - browse and queue removals'
    show_menu_item '3' 'Manage install queue'
    show_menu_item '4' 'Manage remove queue'
    show_menu_item '5' 'Preview changes'
    show_menu_item '6' 'Apply changes'
    show_menu_item '0' 'Cancel'
    echo
    show_input_prompt 'Select an option (0-6):'
    read -r choice
    
    case "$choice" in
      1)
        selected="$(transaction_pick_from_index || true)"
        [[ -z "$selected" ]] && continue
        while IFS= read -r item; do
          [[ -z "$item" ]] && continue
          transaction_expand_and_stage add "$item" || true
        done <<< "$selected"
        show_success 'Addition complete'
        sleep 1
        ;;
      2)
        selected="$(transaction_pick_for_remove || true)"
        [[ -z "$selected" ]] && continue
        while IFS= read -r item; do
          [[ -z "$item" ]] && continue
          transaction_expand_and_stage remove "$item" || true
        done <<< "$selected"
        show_success 'Removal staged'
        sleep 1
        ;;
      3)
        transaction_submenu_install_queue
        ;;
      4)
        transaction_submenu_remove_queue
        ;;
      5)
        clear
        show_logo
        show_section_header 'Transaction Preview'
        echo
        transaction_preview
        wait_for_key
        ;;
      6)
        clear
        show_logo
        show_section_header 'Apply Transaction'
        show_warning 'This will update the lock file with staged changes.'
        show_yes_no_prompt 'Continue?'
        read -r confirm
        if [[ "${confirm,,}" == "y" ]]; then
          transaction_apply
          return 0
        fi
        ;;
      0)
        clear
        show_warning 'Transaction cancelled'
        sleep 1
        return 1
        ;;
      *)
        show_error 'Invalid option.'
        wait_for_key
        ;;
    esac
  done
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

  # Start with current lock entries
  for pkg in "${!TX_LOCK[@]}"; do
    next["$pkg"]=1
  done

  # Add new packages
  for pkg in "${!TX_ADD[@]}"; do
    next["$pkg"]=1
  done

  # Remove packages (AFTER additions to handle conflicts properly)
  for pkg in "${!TX_REMOVE[@]}"; do
    unset next["$pkg"]
  done

  local final=()
  for pkg in "${!next[@]}"; do
    final+=("$pkg")
  done

  write_lock_entries final
  transaction_write_temp
  show_success "Lock updated - Changes will be applied on rebuild"
}

transaction_menu_loop() {
  transaction_menu_loop_tty
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
  local mode="${2:-add}"
  local similar_pkgs count suggested
  
  show_section "Package Not Found: $missing"
  
  # Ensure index exists before searching
  ensure_index
  
  # Find similar packages
  similar_pkgs=$(find_similar_packages "$missing")
  
  if [[ -z "$similar_pkgs" ]]; then
    echo "  No similar packages found."
    echo
    read -r -p "  Skip this package? [Y/n]: " choice
    case "${choice,,}" in
      n) 
        # User wants to browse all packages
        suggested=$(awk -F'|' '{print $1}' "$(get_index_file)" | sort -u | fzf \
          --prompt="BROWSE ALL PACKAGES > " \
          --header="Type to filter | ENTER=select | ESC=cancel" \
          --preview 'get_pkg_description {}' || true)
        
        if [[ -n "$suggested" ]]; then
          if [[ "$mode" == "add" ]]; then
            TX_ADD["$suggested"]=1
            unset TX_REMOVE["$suggested"] 2>/dev/null || true
          else
            TX_REMOVE["$suggested"]=1
            unset TX_ADD["$suggested"] 2>/dev/null || true
          fi
          show_item "✓" "Selected: $suggested"
          return 0
        fi
        return 1
        ;;
      *) 
        return 0 
        ;;
    esac
  fi
  
  # Count matches
  count=$(echo "$similar_pkgs" | wc -l)
  echo "  Found $count similar packages."
  echo
  echo "  What would you like to do?"
  echo "    [1] Select Multiple - Choose any packages from matches"
  echo "    [2] First Match     - Use the first matching package"
  echo "    [3] Browse All      - Browse all packages in fzf"
  echo "    [4] Skip            - Skip this package"
  echo
  read -r -p "  Choose [1-4]: " choice
  
  case "$choice" in
    1)
      # Show fzf with similar packages
      suggested=$(echo "$similar_pkgs" | fzf --multi \
        --prompt="SELECT FROM MATCHES > " \
        --header="TAB=multi | ENTER=confirm | ESC=cancel" \
        --preview 'get_pkg_description {}' || true)
      
      if [[ -n "$suggested" ]]; then
        local pkg_name
        while IFS= read -r pkg_name; do
          [[ -z "$pkg_name" ]] && continue
          if [[ "$mode" == "add" ]]; then
            TX_ADD["$pkg_name"]=1
            unset TX_REMOVE["$pkg_name"] 2>/dev/null || true
          else
            TX_REMOVE["$pkg_name"]=1
            unset TX_ADD["$pkg_name"] 2>/dev/null || true
          fi
        done <<< "$suggested"
        show_item "✓" "Selected from similar packages"
        return 0
      fi
      return 1
      ;;
    2)
      # Use first match
      suggested=$(echo "$similar_pkgs" | head -1)
      if [[ -n "$suggested" ]]; then
        if [[ "$mode" == "add" ]]; then
          TX_ADD["$suggested"]=1
          unset TX_REMOVE["$suggested"] 2>/dev/null || true
        else
          TX_REMOVE["$suggested"]=1
          unset TX_ADD["$suggested"] 2>/dev/null || true
        fi
        show_item "✓" "Selected closest match: $suggested"
        return 0
      fi
      return 1
      ;;
    3)
      # Browse all packages
      suggested=$(awk -F'|' '{print $1}' "$(get_index_file)" | sort -u | fzf --multi \
        --prompt="BROWSE ALL PACKAGES > " \
        --header="Type to filter | TAB=multi | ENTER=confirm | ESC=cancel" \
        --preview 'get_pkg_description {}' || true)
      
      if [[ -n "$suggested" ]]; then
        while IFS= read -r pkg_name; do
          [[ -z "$pkg_name" ]] && continue
          if [[ "$mode" == "add" ]]; then
            TX_ADD["$pkg_name"]=1
            unset TX_REMOVE["$pkg_name"] 2>/dev/null || true
          else
            TX_REMOVE["$pkg_name"]=1
            unset TX_ADD["$pkg_name"] 2>/dev/null || true
          fi
        done <<< "$suggested"
        show_item "✓" "Selected from all packages"
        return 0
      fi
      return 1
      ;;
    4)
      show_item "⊘" "Skipped: $missing"
      return 0
      ;;
    *)
      show_error "Invalid choice"
      return 1
      ;;
  esac
}

import_from_file() {
  local file="$1"
  local route="${2:-import}"
  local normalized token review_answer run_all_answer
  local mode="add"
  local rest segment sign

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

    rest="$token"
    while [[ -n "$rest" ]]; do
      sign="${rest:0:1}"
      if [[ "$sign" == "+" || "$sign" == "-" ]]; then
        [[ "$sign" == "+" ]] && mode="add" || mode="remove"
        rest="${rest:1}"
        continue
      fi

      if [[ "$rest" == *[+-]* ]]; then
        segment="${rest%%[+-]*}"
        rest="${rest:${#segment}}"
      else
        segment="$rest"
        rest=""
      fi

      segment="$(sanitize_token "$segment")"
      [[ -z "$segment" ]] && continue

      if [[ "$mode" == "add" ]]; then
        if transaction_expand_and_stage add "$segment"; then
          continue
        fi
        handle_missing_package "$segment" || show_item "?" "Unresolved: $segment"
      else
        if transaction_expand_and_stage remove "$segment"; then
          continue
        fi
        if is_valid_token "$segment"; then
          TX_REMOVE["$segment"]=1
          unset TX_ADD["$segment"] 2>/dev/null || true
          show_item "-" "Staged raw removal: $segment"
        else
          show_item "?" "Unresolved remove token: $segment"
        fi
      fi
    done
  done <<< "$normalized"

  if [[ "${NIXORCIST_IMPORT_AUTO:-0}" == "1" ]]; then
    transaction_apply
    if [[ ${#TX_REMOVE[@]} -gt 0 ]]; then
      show_info "Removing modules for deleted packages"
      remove_staged_modules
      regenerate_hub
    fi
    transaction_cleanup
    show_info "Import complete ($route)"
    return 0
  fi

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

  if [[ ${#TX_REMOVE[@]} -gt 0 ]]; then
    show_info "Removing modules for deleted packages"
    remove_staged_modules
    regenerate_hub
  fi

  transaction_cleanup

  echo
  read -r -p "  Run full pipeline? [y/N]: " run_all_answer
  case "${run_all_answer,,}" in
    y)
      show_header "Running full pipeline"
      run_rebuild
      ;;
    *)
      show_info "Import complete (changes saved to lock file)"
      show_info "Run 'nixorcist rebuild' to apply changes"
      ;;
  esac
}

module_filename_for_pkg() {
  local pkg="$1"
  echo "$pkg" | tr '/' '-' | tr ' ' '_' | tr ':' '_'
}

remove_staged_modules() {
  local removed_count=0
  local pkg file_name
  
  for pkg in "${!TX_REMOVE[@]}"; do
    file_name="$(module_filename_for_pkg "$pkg")"
    if [[ -f "$MODULES_DIR/$file_name.nix" ]] && grep -qF "$NIXORCIST_MARKER" "$MODULES_DIR/$file_name.nix" 2>/dev/null; then
      rm -f "$MODULES_DIR/$file_name.nix"
      show_item "-" "Removed module: $file_name.nix"
      ((removed_count++))
    fi
  done
  
  [[ $removed_count -gt 0 ]] && return 0
  return 1
}

parse_chant_args() {
  local -n out_add_ref=$1
  local -n out_remove_ref=$2
  shift 2

  out_add_ref=()
  out_remove_ref=()

  local mode="add"
  local raw token rest segment sign

  for raw in "$@"; do
    raw="${raw//,/ }"
    for token in $raw; do
      [[ -z "$token" ]] && continue
      rest="$token"

      while [[ -n "$rest" ]]; do
        sign="${rest:0:1}"
        if [[ "$sign" == "+" || "$sign" == "-" ]]; then
          [[ "$sign" == "+" ]] && mode="add" || mode="remove"
          rest="${rest:1}"
          continue
        fi

        if [[ "$rest" == *[+-]* ]]; then
          segment="${rest%%[+-]*}"
          rest="${rest:${#segment}}"
        else
          segment="$rest"
          rest=""
        fi

        segment="$(sanitize_token "$segment")"
        [[ -z "$segment" ]] && continue

        if ! is_valid_token "$segment"; then
          show_error "Invalid token: $segment"
          continue
        fi

        if [[ "$mode" == "add" ]]; then
          out_add_ref+=("$segment")
        else
          out_remove_ref+=("$segment")
        fi
      done
    done
  done
}

install_from_args() {
  if [[ $# -eq 0 ]]; then
    show_error "install requires at least one package"
    return 1
  fi

  local tmp_file

  tmp_file="$(mktemp /tmp/nixorcist-install-args.XXXXXX)"
  printf '%s\n' "$@" > "$tmp_file"

  NIXORCIST_IMPORT_AUTO=1 import_from_file "$tmp_file" install
  rm -f "$tmp_file"
}

delete_from_args() {
  if [[ $# -eq 0 ]]; then
    show_error "delete requires at least one package"
    return 1
  fi

  local tmp_file
  tmp_file="$(mktemp /tmp/nixorcist-delete-args.XXXXXX)"

  # Force remove mode first; inline + and - switches are still supported afterwards.
  printf '%s\n' '-' > "$tmp_file"
  printf '%s\n' "$@" >> "$tmp_file"

  NIXORCIST_IMPORT_AUTO=1 import_from_file "$tmp_file" delete
  rm -f "$tmp_file"
}

chant_from_args() {
  if [[ $# -eq 0 ]]; then
    show_error "chant requires package arguments"
    return 1
  fi

  local tmp_file
  tmp_file="$(mktemp /tmp/nixorcist-chant-args.XXXXXX)"
  printf '%s\n' "$@" > "$tmp_file"

  NIXORCIST_IMPORT_AUTO=1 import_from_file "$tmp_file" chant
  rm -f "$tmp_file"

  show_success "Chant complete"
}
