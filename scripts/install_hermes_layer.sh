#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-}"
if [[ -z "$MODE" ]]; then
  MODE="--install"
fi
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_EXISTING="$HOME/.hermes/hermes-agent"
HERMES_REPO_URL="${HERMES_REPO_URL:-https://github.com/NousResearch/hermes-agent.git}"
HERMES_HOME="${HERMES_HOME:-$HOME/.hermes/hermes-agent}"
LAYER_HOME="${JOBMAXXING_HERMES_LAYER_HOME:-$HOME/.jobmaxxing/hermes-layer}"
GIT_TIMEOUT_SECONDS="${HERMES_GIT_TIMEOUT_SECONDS:-12}"

if [[ -d "${HERMES_PATH:-}" ]]; then
  HERMES_DIR="$HERMES_PATH"
elif [[ -d "$DEFAULT_EXISTING" ]]; then
  HERMES_DIR="$DEFAULT_EXISTING"
else
  HERMES_DIR="$HERMES_HOME"
fi

usage() {
  cat <<USAGE
usage: scripts/install_hermes_layer.sh [--install|--update|--status|--doctor]

Environment:
  HERMES_PATH       Existing Hermes checkout path.
  HERMES_HOME       Install path when cloning is needed. Default: $HERMES_HOME
  HERMES_REPO_URL   Hermes repository URL. Default: $HERMES_REPO_URL
USAGE
}

ensure_hermes() {
  if [[ -d "$HERMES_DIR/.git" || -x "$HERMES_DIR/hermes" || -f "$HERMES_DIR/setup-hermes.sh" ]]; then
    return
  fi
  echo "Cloning Hermes into $HERMES_DIR"
  mkdir -p "$(dirname "$HERMES_DIR")"
  git clone "$HERMES_REPO_URL" "$HERMES_DIR"
}

run_git() {
  local output_file status_file pid elapsed status
  output_file="$(mktemp)"
  status_file="$(mktemp)"
  (
    git -C "$HERMES_DIR" "$@" >"$output_file" 2>&1
    echo "$?" >"$status_file"
  ) &
  pid="$!"
  elapsed=0

  while kill -0 "$pid" 2>/dev/null; do
    if (( elapsed >= GIT_TIMEOUT_SECONDS )); then
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      cat "$output_file" >&2
      rm -f "$output_file" "$status_file"
      echo "Timed out running git $* in $HERMES_DIR" >&2
      return 124
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done

  wait "$pid" 2>/dev/null || true
  status="$(cat "$status_file" 2>/dev/null || echo 1)"
  cat "$output_file"
  rm -f "$output_file" "$status_file"
  return "$status"
}

is_git_clean() {
  [[ -d "$HERMES_DIR/.git" ]] || return 0
  echo "Checking Hermes tracked files: $HERMES_DIR" >&2
  run_git diff-index --quiet HEAD --
}

update_hermes() {
  ensure_hermes
  if [[ ! -d "$HERMES_DIR/.git" ]]; then
    echo "Hermes path is not a git checkout: $HERMES_DIR" >&2
    return 1
  fi
  if ! is_git_clean; then
    if [[ "${HERMES_ALLOW_DIRTY:-0}" != "1" ]]; then
      echo "Hermes git check did not complete. Skipping Hermes fast-forward and reinstalling the Jobmaxxing layer only." >&2
      return 0
    fi
    echo "Hermes git check did not complete. HERMES_ALLOW_DIRTY=1 is set, so trying fast-forward anyway." >&2
  fi
  echo "Fetching Hermes main"
  run_git fetch origin main
  echo "Checking out Hermes main"
  run_git checkout main
  echo "Fast-forwarding Hermes main"
  run_git pull --ff-only origin main
}

install_layer() {
  ensure_hermes
  echo "Installing Jobmaxxing layer into $LAYER_HOME"
  mkdir -p "$LAYER_HOME/skills" "$LAYER_HOME/tools" "$LAYER_HOME/prompts"
  python3 "$ROOT_DIR/scripts/export_hermes_commands.py" \
    --hermes-path "$HERMES_DIR" \
    --output "$LAYER_HOME/hermes-commands.json"
  cp "$ROOT_DIR/hermes/jobmaxxing.hermes.json" "$LAYER_HOME/jobmaxxing.hermes.json"
  cp "$ROOT_DIR/hermes/tools/jobmaxxing-toolset.json" "$LAYER_HOME/tools/jobmaxxing-toolset.json"
  cp "$ROOT_DIR/hermes/prompts/jobmaxxing-system.md" "$LAYER_HOME/prompts/jobmaxxing-system.md"
  rm -rf "$LAYER_HOME/skills/jobmaxxing-orchestrator"
  cp -R "$ROOT_DIR/hermes/skills/jobmaxxing-orchestrator" "$LAYER_HOME/skills/jobmaxxing-orchestrator"

  cat >"$LAYER_HOME/jobmaxxing.env" <<ENV
JOBMAXXING_ROOT="$ROOT_DIR"
JOBMAXXING_MCP_COMMAND="npm run mcp --prefix $ROOT_DIR"
JOBMAXXING_HERMES_LAYER="$LAYER_HOME/jobmaxxing.hermes.json"
JOBMAXXING_HERMES_SYSTEM_PROMPT="$LAYER_HOME/prompts/jobmaxxing-system.md"
HERMES_PATH="$HERMES_DIR"
ENV

  cat >"$LAYER_HOME/README.md" <<README
# Jobmaxxing Hermes Layer

Hermes checkout: \`$HERMES_DIR\`
Jobmaxxing repo: \`$ROOT_DIR\`

Load:
- \`$LAYER_HOME/prompts/jobmaxxing-system.md\`
- \`$LAYER_HOME/skills/jobmaxxing-orchestrator/SKILL.md\`
- \`$LAYER_HOME/tools/jobmaxxing-toolset.json\`
- \`$LAYER_HOME/hermes-commands.json\`

Update with:

\`\`\`bash
$ROOT_DIR/scripts/hermes_update.sh
\`\`\`
README

  echo "Installed Jobmaxxing Hermes layer"
  echo "Hermes: $HERMES_DIR"
  echo "Layer: $LAYER_HOME"
  echo "Keep Hermes configured to load the external layer path; the installer does not modify the Hermes checkout."
}

status_layer() {
  echo "Hermes path: $HERMES_DIR"
  if [[ -d "$HERMES_DIR/.git" ]]; then
    echo "Hermes git: checkout present"
  else
    echo "Hermes git: not available"
  fi
  if [[ -f "$LAYER_HOME/jobmaxxing.hermes.json" ]]; then
    echo "Layer: installed at $LAYER_HOME"
  else
    echo "Layer: not installed"
  fi
  if grep -q '^\[mcp_servers\.jobmaxxing\]' "$HOME/.codex/config.toml" 2>/dev/null; then
    echo "Codex MCP: configured"
  else
    echo "Codex MCP: missing"
  fi
}

doctor_layer() {
  status_layer
  command -v git >/dev/null && echo "git: available" || echo "git: missing"
  command -v npm >/dev/null && echo "npm: available" || echo "npm: missing"
  [[ -f "$ROOT_DIR/hermes/jobmaxxing.hermes.json" ]] && echo "manifest: present" || echo "manifest: missing"
  [[ -f "$ROOT_DIR/scripts/hermes_update.sh" ]] && echo "slash update: present" || echo "slash update: missing"
  [[ -f "$LAYER_HOME/hermes-commands.json" ]] && echo "Hermes commands: exported" || echo "Hermes commands: missing"
}

case "$MODE" in
  --install|install)
    install_layer
    ;;
  --update|update)
    update_hermes
    install_layer
    ;;
  --status|status)
    status_layer
    ;;
  --doctor|doctor)
    doctor_layer
    ;;
  --help|-h|help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
