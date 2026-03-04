generate_modules() {
  echo "Generating modules from lock..."

  mapfile -t packages < <(read_lock_entries)

  for pkg in "${packages[@]}"; do

    if ! is_derivation "$pkg"; then
      echo "Skipping non-derivation: $pkg"
      continue
    fi

    safe_name=$(echo "$pkg" | tr '/' '-' | tr ' ' '_' | tr ':' '_')
    target="$MODULES_DIR/$safe_name.nix"

    if [[ -f "$target" ]]; then
      echo "exists: $safe_name.nix"
      continue
    fi

    cat > "$target" <<EOF
{ pkgs }:

pkgs.$pkg

$NIXORCIST_MARKER
# NIXORCIST-ATTRPATH: $pkg
EOF

    echo "spawned: $safe_name.nix"
  done
}
