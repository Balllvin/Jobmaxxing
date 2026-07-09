#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HERMES_BIN="${HERMES_BIN:-hermes}"

"$HERMES_BIN" update "$@"
"$ROOT_DIR/scripts/install_hermes_layer.sh" --install
