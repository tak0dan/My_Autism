#!/usr/bin/env bash
set -euo pipefail

ROOT="/etc/nixos/nixorcist"
export ROOT

# Load directories first
source "$ROOT/lib/dirs.sh"
prepare_dirs

# Load rest
for lib in lock gen hub rebuild utils index; do
  source "$ROOT/lib/$lib.sh"
done

case "${1:-}" in

  select)
    select_packages
    ;;
  gen)
    generate_modules
    ;;
  hub)
    regenerate_hub
    ;;
  rebuild)
    run_rebuild
    ;;
  purge)
    purge_all_modules
    ;;
  import)
    shift
    import_from_file "${1:-}"
    ;;
  all)
    select_packages
    generate_modules
    regenerate_hub
    run_rebuild
    ;;
  *)
    echo "Usage: nixorcist {select|gen|hub|rebuild|all|purge|import <file>}"
    ;;
esac

# Upgraded importing mechanism
import_from_file() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo "Error: File '$file' not found"
    exit 1
  fi

  echo "Importing packages from '$file'..."

  local imported=0
  local skipped=0
  local invalid=0

  while IFS= read -r pkg || [[ -n "$pkg" ]]; do
    # Skip empty lines and comments
    [[ -z "$pkg" || "$pkg" =~ ^[[:space:]]*# ]] && continue

    # Trim whitespace
    pkg=$(echo "$pkg" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    if [[ -z "$pkg" ]]; then
      continue
    fi

    # Validate package exists
    if ! is_derivation "$pkg"; then
      echo "Warning: '$pkg' is not a valid package, skipping"
      ((invalid++))
      continue
    fi

    # Check if already in lock
    if grep -q "^${pkg}$" "$LOCK_FILE" 2>/dev/null; then
      echo "Skipping already imported: $pkg"
      ((skipped++))
      continue
    fi

    echo "$pkg" >> "$LOCK_FILE"
    echo "Imported: $pkg"
    ((imported++))
  done < "$file"

  echo "Import complete: $imported imported, $skipped skipped, $invalid invalid"
}
