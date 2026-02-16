#!/usr/bin/env bash

set -euo pipefail

echo "[post-create] Upgrading pip ..."
python3 -m pip install --upgrade pip

echo "[post-create] Installing specify CLI (spec-kit)"
if command -v specify &>/dev/null; then
    echo "specify already installed — skipping"
else
    # Ensure uv is available (needed for uv tool install)
    if ! command -v uv &>/dev/null; then
        echo "uv not found - Please add the uv feature to your devContainer; ghcr.io/devcontainers-extra/features/uv:1"
        exit 1
    fi
    uv tool install specify-cli --from "git+https://github.com/github/spec-kit.git"
fi
