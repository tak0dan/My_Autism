#!/usr/bin/env bash

INDEX_DIR="$ROOT/cache"
INDEX_FILE="$INDEX_DIR/nixpkgs-index.txt"
INDEX_VERSION="3"
INDEX_VERSION_FILE="$INDEX_DIR/nixpkgs-index.version"

build_nix_index() {

  echo "Building nixpkgs index..." >&2

  mkdir -p "$INDEX_DIR"

  local tmp_a="" tmp_b="" tmp_c="" tmp_all="" line_count=""
  tmp_a="$(mktemp)"
  tmp_b="$(mktemp)"
  tmp_c="$(mktemp)"
  tmp_all="$(mktemp)"
  trap 'rm -f "${tmp_a:-}" "${tmp_b:-}" "${tmp_c:-}" "${tmp_all:-}"' RETURN

  # Source A: broad package list from nix-env (captures nested package attrs).
  if command -v nix-env >/dev/null 2>&1; then
    if nix-env -f '<nixpkgs>' -qaP --description 2>/dev/null \
      | awk '{
          attr=$1;
          if (attr == "") next;
          $1="";
          $2="";
          sub(/^[[:space:]]+/, "", $0);
          gsub(/\|/, "/", $0);
          print attr "|" $0;
        }' > "$tmp_a"; then
      :
    fi
  fi

  # Source B: top-level attrs from nix eval (keeps attrset entries available).
  if nix eval --impure --raw --expr '
    let
      pkgs = import <nixpkgs> {};
      names = builtins.attrNames pkgs;

      format = name:
        let
          val = builtins.tryEval pkgs.${name};
        in
          if val.success && builtins.isAttrs val.value then
            name + "|" + (val.value.meta.description or "")
          else
            name + "|";
    in
      builtins.concatStringsSep "\n" (map format names)
  ' > "$tmp_b" 2>/dev/null; then
    :
  fi

  # Source C: flake-based recursive scan to capture nested attrpaths such as
  # eclipses.eclipse-java and libsForQt5.qtmultimedia when NIX_PATH-based
  # commands are unavailable.
  if nix eval --impure --raw --expr '
    let
      flake = builtins.getFlake "flake:nixpkgs";
      pkgs = flake.legacyPackages.${builtins.currentSystem};

      walk = depth: prefix: attrs:
        if depth > 2 || !(builtins.isAttrs attrs) then
          []
        else
          builtins.concatLists (map (name:
            let
              path = if prefix == "" then name else prefix + "." + name;
              valueEval = builtins.tryEval attrs.${name};
            in
              if !valueEval.success then
                []
              else
                let
                  value = valueEval.value;
                  isAttrs = builtins.isAttrs value;
                  isDrv = isAttrs && (value.type or null) == "derivation";
                  desc = if isDrv then (value.meta.description or "") else "";
                  line = [ (path + "|" + desc) ];
                  next = if isAttrs && !isDrv then walk (depth + 1) path value else [];
                in
                  line ++ next
          ) (builtins.attrNames attrs));
    in
      builtins.concatStringsSep "\n" (walk 0 "" pkgs)
  ' > "$tmp_c" 2>/dev/null; then
    :
  fi

  cat "$tmp_a" "$tmp_b" "$tmp_c" \
    | awk -F'|' '
      {
        attr=$1;
        desc=$2;
        if (attr == "") next;
        if (!(attr in best) || (best[attr] == "" && desc != "")) {
          best[attr] = desc;
        }
      }
      END {
        for (attr in best) {
          print attr "|" best[attr];
        }
      }
    ' \
    | sort -f > "$tmp_all"

  line_count="$(wc -l < "$tmp_all" | tr -d '[:space:]')"
  if [[ -z "$line_count" || "$line_count" -eq 0 ]]; then
    echo "Failed to build nixpkgs index from all sources." >&2
    return 1
  fi

  mv "$tmp_all" "$INDEX_FILE"
  printf '%s\n' "$INDEX_VERSION" > "$INDEX_VERSION_FILE"

  echo "Index written to $INDEX_FILE ($line_count entries)" >&2
}
