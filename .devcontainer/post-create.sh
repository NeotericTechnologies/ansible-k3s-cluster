#!/usr/bin/env bash
set -euo pipefail
export SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"

echo "[post-create] Upgrading pip ..."
python3 -m pip install --upgrade pip

echo "[post-create] Installing specify CLI (spec-kit) ..."
source "${SCRIPT_DIR}/installSpecKit"

echo "[post-create] Installing Test Connection ..."
source "${SCRIPT_DIR}/installTestConnection"
