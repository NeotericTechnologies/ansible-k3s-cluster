#!/usr/bin/env bash
set -euo pipefail
export SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"

echo "[post-start] Upgrading specify CLI to ensure we have the latest features and fixes"
source "${SCRIPT_DIR}/upgradeSpecKit"
