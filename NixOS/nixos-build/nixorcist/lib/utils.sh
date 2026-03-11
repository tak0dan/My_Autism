#!/usr/bin/env bash


get_index_file() {
  echo "$ROOT/cache/nixpkgs-index.txt"
}

ensure_index() {

  local index
  index=$(get_index_file)

  if [[ ! -f "$index" ]]; then
    build_nix_index
  fi
}

get_pkg_description() {
  nix eval --impure --raw --expr "
    let
      pkgs = import <nixpkgs> {};
      val = builtins.tryEval pkgs.${1};
    in
      if val.success && builtins.isAttrs val.value && (val.value.type or null) == \"derivation\"
      then
        (val.value.meta.description or \"No description\")
      else if val.success && builtins.isAttrs val.value
      then
        \"Attribute set\"
      else
        \"Not a package\"
  " 2>/dev/null
}

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
  nix eval --impure --expr "
    let
      pkgs = import <nixpkgs> {};
      val = pkgs.${1};
    in
      builtins.isAttrs val && (val.type or null) == \"derivation\"
  " 2>/dev/null | grep -q true
}

is_attrset() {
  nix eval --impure --expr "
    let
      pkgs = import <nixpkgs> {};
      val = builtins.tryEval pkgs.${1};
    in
      val.success && builtins.isAttrs val.value &&
      (val.value.type or null) != \"derivation\"
  " 2>/dev/null | grep -q true
}

list_attrset_children() {
  nix eval --impure --raw --expr "
    let
      pkgs = import <nixpkgs> {};
    in
      builtins.concatStringsSep \"\n\" (builtins.attrNames pkgs.${1})
  " 2>/dev/null
}

is_valid_token() {
  local token="$1"
  [[ -n "$token" ]] && [[ "$token" =~ ^[a-zA-Z0-9._+-]+$ ]]
}

sanitize_token() {
  local token="$1"
  token="${token,,}"
  token="$(echo "$token" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  echo "$token"
}

resolve_entry_to_packages() {
  local entry="$1"
  local -n out_ref=$2
  out_ref=()

  if is_derivation "$entry"; then
    out_ref+=("$entry")
    return 0
  fi

  if is_attrset "$entry"; then
    local child resolved
    while IFS= read -r child; do
      [[ -z "$child" ]] && continue
      resolved="$entry.$child"
      if is_derivation "$resolved"; then
        out_ref+=("$resolved")
      fi
    done < <(list_attrset_children "$entry")

    [[ ${#out_ref[@]} -gt 0 ]]
    return
  fi

  return 1
}

get_pkg_type() {
  local entry="$1"
  if is_derivation "$entry"; then
    echo "package"
  elif is_attrset "$entry"; then
    echo "attrset"
  else
    echo "unknown"
  fi
}

count_attrset_packages() {
  local entry="$1"
  local child resolved count=0
  
  while IFS= read -r child; do
    [[ -z "$child" ]] && continue
    resolved="$entry.$child"
    if is_derivation "$resolved"; then
      ((count++))
    fi
  done < <(list_attrset_children "$entry")
  
  echo "$count"
}

find_similar_packages() {
  local query="$1"
  local index_file="$(get_index_file)"
  
  awk -F'|' -v q="$query" 'tolower($1) ~ tolower(q) {print $1}' "$index_file" 2>/dev/null | sort -u | head -30
}
