#!/usr/bin/env bash
set -euo pipefail

export PATH="/root/.local/bin:$PATH"
export SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
. "${SCRIPT_DIR}/commonFunctions"

printTitle "Upgrading specify CLI to ensure we have the latest features and fixes ..."
source "${SCRIPT_DIR}/upgradeSpecKit"

printTitle "Initializing RTK ..."
source "${SCRIPT_DIR}/initializeRtk"
