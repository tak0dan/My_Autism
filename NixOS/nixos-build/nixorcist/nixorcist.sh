#!/usr/bin/env bash
set -euo pipefail

ROOT="/etc/nixos/nixorcist"
export ROOT

# Load directories first
source "$ROOT/lib/dirs.sh"
prepare_dirs

# Load CLI interface
source "$ROOT/lib/cli.sh"

# Load all libraries
for lib in utils lock gen hub rebuild index; do
  source "$ROOT/lib/$lib.sh"
done

main() {
  local command="${1:-help}"

  case "$command" in
    transaction)
      show_header "Transaction Builder"
      run_transaction_cli
      show_success "Transaction completed"
      ;;
    select)
      show_header "Package Selection (Interactive)"
      select_packages
      ;;
    gen)
      show_header "Generating Modules"
      generate_modules
      ;;
    hub)
      show_header "Regenerating Hub"
      regenerate_hub
      ;;
    rebuild)
      show_header "NixOS Rebuild"
      run_rebuild
      ;;
    purge)
      show_header "Purging Modules"
      purge_all_modules
      ;;
    import)
      if [[ -z "${2:-}" ]]; then
        show_error "import requires a file path"
        echo "Usage: nixorcist import <file>"
        return 1
      fi
      show_header "Importing from $2"
      import_from_file "$2"
      ;;
    all)
      show_header "Full Pipeline: select → gen → hub → rebuild"
      run_transaction_cli && \
      generate_modules && \
      regenerate_hub && \
      run_rebuild && \
      show_success "Full pipeline completed"
      ;;
    help|-h|--help)
      show_logo
      show_menu
      ;;
    *)
      show_error "Unknown command: $command"
      echo
      echo "  Run 'nixorcist help' for usage information."
      exit 1
      ;;
  esac
}

main "$@"
