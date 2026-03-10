#!/usr/bin/env bash

run_rebuild() {
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  ROOT_DIR="$(realpath "$SCRIPT_DIR/../..")"

  echo "→ Creating staging snapshot"

  rm -rf /etc/nixos/.staging
  mkdir -p /etc/nixos/.staging

  cp -r /etc/nixos/* /etc/nixos/.staging/

  echo "→ Validating build"

  nix-build '<nixpkgs/nixos>' \
    --attr config.system.build.toplevel \
    --include nixos-config=/etc/nixos/.staging/configuration.nix

  echo "→ Build successful"
  echo "→ Promoting staging to live config"

  "$ROOT_DIR/scripts/nix-rebuild-smart.sh"

  # Clean up .staging: keep only files related to current declarations
  echo "→ Cleaning up .staging directory"
  if [[ -d /etc/nixos/.staging ]]; then
    # List of files to keep: configuration.nix and all generated modules
    keep_files=("configuration.nix")
    if [[ -d /etc/nixos/.staging/nixorcist/generated/.modules ]]; then
      while IFS= read -r f; do
        keep_files+=("nixorcist/generated/.modules/$(basename "$f")")
      done < <(find /etc/nixos/.staging/nixorcist/generated/.modules -type f -name '*.nix')
    fi
    # Remove everything except keep_files
    find /etc/nixos/.staging -type f | while read -r file; do
      rel="${file#/etc/nixos/.staging/}"
      skip=0
      for k in "${keep_files[@]}"; do
        [[ "$rel" == "$k" ]] && skip=1 && break
      done
      [[ $skip -eq 0 ]] && rm -f "$file"
    done
  fi

  echo "→ Done"
}
