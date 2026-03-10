#!/usr/bin/env bash
# Beautiful CLI interface for nixorcist

show_logo() {
  cat << 'LOGO'

 ███╗   ██╗██╗██╗  ██╗ ██████╗ ██████╗  ██████╗███████╗██╗███████╗████████╗
 ████╗  ██║██║╚██╗██╔╝██╔═══██╗██╔══██╗██╔════╝██╔════╝██║██╔════╝╚══██╔══╝
 ██╔██╗ ██║██║ ╚███╔╝ ██║   ██║██████╔╝██║     █████╗  ██║███████╗   ██║
 ██║╚██╗██║██║ ██╔██╗ ██║   ██║██╔══██╗██║     ██╔══╝  ██║╚════██║   ██║
 ██║ ╚████║██║██╔╝ ██╗╚██████╔╝██║  ██║╚██████╗███████╗██║███████║   ██║
 ╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝ ╚═════╝╚══════╝╚═╝╚══════╝   ╚═╝

        The declarative NixOS package sorcerer

LOGO
}

show_menu() {
  cat << 'MENU'

  ╔════════════════════════════════════════════════════════════════╗
  ║                     Command Reference                         ║
  ╠════════════════════════════════════════════════════════════════╣
  ║                                                                ║
  ║  transaction   Interactive add/remove in one flow              ║
  ║  select        Classic add/remove (uses transaction)           ║
  ║  import FILE   Import packages from file interactively         ║
  ║  gen           Generate Nix modules from lock                  ║
  ║  hub           Regenerate hub (all-packages.nix)               ║
  ║  rebuild       NixOS rebuild with staging & cleanup            ║
  ║  all           Full pipeline: select → gen → hub → rebuild     ║
  ║  purge         Remove all generated modules & clear lock       ║
  ║  help          Show this help message                          ║
  ║                                                                ║
  ║  Examples:                                                      ║
  ║    nixorcist transaction    # Stage packages and apply         ║
  ║    nixorcist import list.txt # Import from file                ║
  ║    nixorcist all            # Complete workflow                ║
  ║                                                                ║
  ╚════════════════════════════════════════════════════════════════╝

MENU
}

show_divider() {
  printf '  ─────────────────────────────────────────────────────────────\n'
}

show_header() {
  local title="$1"
  echo
  printf '  ▶ %s\n' "$title"
  show_divider
}

show_section() {
  local title="$1"
  echo
  printf '  ╭─ %s\n' "$title"
}

show_error() {
  local msg="$1"
  printf '  ✗ Error: %s\n' "$msg" >&2
}

show_success() {
  local msg="$1"
  printf '  ✓ %s\n' "$msg"
}

show_info() {
  local msg="$1"
  printf '  ℹ %s\n' "$msg"
}

show_item() {
  local status="$1"
  local msg="$2"
  printf '  %s %s\n' "$status" "$msg"
}
