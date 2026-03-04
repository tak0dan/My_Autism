#!/usr/bin/env bash
set -euo pipefail

BASE="/etc/nixos"
STAGING="$BASE/.staging"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

echo "→ Creating staging snapshot"
rm -rf "$STAGING"
mkdir -p "$STAGING"

rsync -a --delete \
  --exclude '.staging' \
  "$BASE/" "$STAGING/"

echo "→ Regenerating all-packages.nix"
"$SCRIPT_DIR/generate-packages.sh" > "$STAGING/modules/all-packages.nix"

echo "→ Validating build"

if nixos-rebuild build -I nixos-config="$STAGING/configuration.nix"; then
    echo "→ Build successful"
    echo "→ Promoting staging to live config"

    rm -rf "$BASE/modules"
    mv "$STAGING/modules" "$BASE/"

    nixos-rebuild switch
    rm -rf "$STAGING"

    echo "→ Done"
else
    echo "✗ Build failed. Nothing was changed."
    rm -rf "$STAGING"
    exit 1
fi
