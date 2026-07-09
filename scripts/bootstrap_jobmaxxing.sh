#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"
npm install
"$ROOT_DIR/scripts/install_codex_mcp.sh"
"$ROOT_DIR/scripts/install_hermes_layer.sh" --install

echo "Jobmaxxing bootstrap complete."
echo "Run the native app with: ./script/build_and_run.sh"
