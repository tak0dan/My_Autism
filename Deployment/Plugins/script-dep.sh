#!/usr/bin/env bash
set -euo pipefail

echo "Running dependency script for: $BASENAME"

if [[ -x "$SOURCE" ]]; then
    bash "$SOURCE"
else
    chmod +x "$SOURCE"
    bash "$SOURCE"
fi
