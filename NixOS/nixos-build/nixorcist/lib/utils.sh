#!/usr/bin/env bash

list_available_packages() {
  nix eval --impure --raw --expr '
    let pkgs = import <nixpkgs> {};
        system = builtins.currentSystem or "x86_64-linux";
        set = pkgs.legacyPackages."${system}" or pkgs;
    in builtins.concatStringsSep "\n" (builtins.attrNames set)
  '
}

list_available_packages_lower() {
  list_available_packages | tr '[:upper:]' '[:lower:]'
}

purge_all_modules() {
  rm -f "$MODULES_DIR"/*.nix
  > "$LOCK_FILE"
  echo "Everything purged."
}

# --- package validation ---

is_derivation() {
  local pkg="$1"

  nix eval --impure --raw --expr "
    let pkgs = import <nixpkgs> {};
    in if pkgs ? \"$pkg\" && pkgs.$pkg ? type
       then pkgs.$pkg.type
       else \"invalid\"
  " 2>/dev/null | grep -q derivation
}
