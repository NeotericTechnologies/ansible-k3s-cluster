#!/usr/bin/env bash
set -euo pipefail

export PATH="/root/.local/bin:$PATH"
export SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
. "${SCRIPT_DIR}/commonFunctions"

printTitle "Upgrading pip ..."
python3 -m pip install --upgrade pip

printTitle "Make Node, NPM, NPX available globally ..."
sudo ln -s $(which node) /usr/local/bin/node
sudo ln -s $(which npm) /usr/local/bin/npm
sudo ln -s $(which npx) /usr/local/bin/npx

printTitle "Installing specify CLI (spec-kit) ..."
source "${SCRIPT_DIR}/installSpecKit"

printTitle "Installing testConnection ..."
source "${SCRIPT_DIR}/installTestConnection"

printTitle "Installing Caveman Skills ..."
source "${SCRIPT_DIR}/installCaveman"

printTitle "Installing RTK ..."
source "${SCRIPT_DIR}/installRtk"

printTitle "Installing Codebase Memory MCP ..."
source "${SCRIPT_DIR}/installCodebaseMemoryMcp"
