#!/usr/bin/env bash

INDEX_DIR="$ROOT/cache"
INDEX_FILE="$INDEX_DIR/nixpkgs-index.txt"
INDEX_VERSION="2"
INDEX_VERSION_FILE="$INDEX_DIR/nixpkgs-index.version"

build_nix_index() {

  echo "Building nixpkgs index..."

  mkdir -p "$INDEX_DIR"

  local tmp_a="" tmp_b="" tmp_all="" line_count=""
  tmp_a="$(mktemp)"
  tmp_b="$(mktemp)"
  tmp_all="$(mktemp)"
  trap 'rm -f "${tmp_a:-}" "${tmp_b:-}" "${tmp_all:-}"' RETURN

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

  cat "$tmp_a" "$tmp_b" \
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

  echo "Index written to $INDEX_FILE ($line_count entries)"
}
