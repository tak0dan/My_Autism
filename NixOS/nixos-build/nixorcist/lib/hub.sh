#!/usr/bin/env bash

regenerate_hub() {
  HUB="$ROOT/generated/all-packages.nix"

  echo "Regenerating hub..."

  {
    echo "{ config, pkgs, ... }:"
    echo "{"
    echo "  imports = ["
    for f in "$MODULES_DIR"/*.nix; do
      echo "    ./.modules/$(basename "$f")"
    done
    echo "  ];"
    echo "}"
  } > "$HUB"

  echo "hub regenerated."
}
