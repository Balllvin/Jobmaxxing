#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_DIR="$HOME/.codex"
CONFIG_FILE="$CONFIG_DIR/config.toml"
BACKUP_FILE="$CONFIG_DIR/config.toml.jobmaxxing.bak"

mkdir -p "$CONFIG_DIR"
touch "$CONFIG_FILE"

if grep -q '^\[mcp_servers\.jobmaxxing\]' "$CONFIG_FILE"; then
  echo "Jobmaxxing MCP already configured in $CONFIG_FILE"
  exit 0
fi

cp "$CONFIG_FILE" "$BACKUP_FILE"

cat >>"$CONFIG_FILE" <<TOML

[mcp_servers.jobmaxxing]
command = "npm"
args = ["run", "mcp", "--prefix", "$ROOT_DIR"]
startup_timeout_sec = 30.0
tool_timeout_sec = 120.0
TOML

echo "Installed Jobmaxxing MCP in $CONFIG_FILE"
echo "Backup written to $BACKUP_FILE"
