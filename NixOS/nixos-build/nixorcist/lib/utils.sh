#!/usr/bin/env bash

# ---------------------------------------------------------------------------
# NIX_PATH auto-detection
# All nix eval calls in this file go through "${_nix_pkg_args[@]}" so that
# <nixpkgs> resolves even when NIX_PATH is not propagated by sudo.
# Priority: (1) flake ref  (2) channel auto-detect  (3) NIX_PATH as-is
# ---------------------------------------------------------------------------
declare -a _nix_pkg_args=()
_nix_pkg_args_ready=0

_init_nix_pkg_args() {
  if [[ "$_nix_pkg_args_ready" -eq 1 ]]; then return 0; fi
  _nix_pkg_args_ready=1
  # Already works → nothing extra needed
  if nix eval --raw --impure --expr 'builtins.toString <nixpkgs>' &>/dev/null; then
    return 0
  fi
  # Try common channel paths (root channels, SUDO_USER channels)
  local p
  for p in \
    "/nix/var/nix/profiles/per-user/root/channels/nixpkgs" \
    "/root/.nix-defexpr/channels/nixpkgs" \
    "/nix/var/nix/profiles/per-user/${SUDO_USER:-}/channels/nixpkgs" \
    "/home/${SUDO_USER:-}/.nix-defexpr/channels/nixpkgs"
  do
    if [[ -d "$p" && -f "$p/default.nix" ]]; then
      _nix_pkg_args=(-I "nixpkgs=$p")
      return 0
    fi
  done
}

get_index_file() {
  echo "$ROOT/cache/nixpkgs-index.txt"
}

ensure_index() {

  local index
  local version_file expected_version current_version
  index=$(get_index_file)
  version_file="$ROOT/cache/nixpkgs-index.version"
  expected_version="2"

  if [[ ! -f "$index" ]]; then
    build_nix_index
    return
  fi

  current_version=""
  if [[ -f "$version_file" ]]; then
    current_version="$(head -n1 "$version_file" 2>/dev/null | tr -d '[:space:]')"
  fi

  if [[ "$current_version" != "$expected_version" ]]; then
    build_nix_index
  fi
}

get_pkg_description() {
  local pkg="$1"
  # Try flake-based lookup first (no NIX_PATH needed)
  local flake_type
  flake_type=$(nix eval --impure "nixpkgs#${pkg}.type" 2>/dev/null) || true
  if [[ "$flake_type" == '"derivation"' ]]; then
    nix eval --impure --raw "nixpkgs#${pkg}.meta.description" 2>/dev/null || echo "No description"
    return
  fi
  # Fallback: channel-based eval
  _init_nix_pkg_args
  nix eval --impure "${_nix_pkg_args[@]}" --raw --expr "
    let
      pkgs = import <nixpkgs> {};
      val = builtins.tryEval pkgs.${pkg};
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
  return 0
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
  local pkg="$1"
  # Try flake reference first (works on flakes-enabled NixOS without NIX_PATH)
  local flake_type
  flake_type=$(nix eval --impure "nixpkgs#${pkg}.type" 2>/dev/null) || true
  [[ "$flake_type" == '"derivation"' ]] && return 0
  # Fallback: channel-based eval
  _init_nix_pkg_args
  nix eval --impure "${_nix_pkg_args[@]}" --expr "
    let
      pkgs = import <nixpkgs> {};
      val = pkgs.${pkg};
    in
      builtins.isAttrs val && (val.type or null) == \"derivation\"
  " 2>/dev/null | grep -q true
}

is_attrset() {
  local pkg="$1"
  # Fast path: if it IS a derivation it cannot be an attrset
  is_derivation "$pkg" && return 1
  # Channel-based check
  _init_nix_pkg_args
  nix eval --impure "${_nix_pkg_args[@]}" --expr "
    let
      pkgs = import <nixpkgs> {};
      val = builtins.tryEval pkgs.${pkg};
    in
      val.success && builtins.isAttrs val.value &&
      (val.value.type or null) != \"derivation\"
  " 2>/dev/null | grep -q true
}

list_attrset_children() {
  _init_nix_pkg_args
  nix eval --impure "${_nix_pkg_args[@]}" --raw --expr "
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
  # Keep original case; Nix attribute paths are case-sensitive.
  token="${token//$'\r'/}"
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
