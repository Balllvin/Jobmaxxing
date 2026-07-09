#!/usr/bin/env python3
"""Export Hermes slash commands from the installed Hermes registry.

The Hermes repository keeps slash commands in hermes_cli/commands.py as
COMMAND_REGISTRY. Jobmaxxing should not maintain a separate hand-written list.
This script parses that registry without importing Hermes, so optional Hermes
runtime dependencies cannot break the export.
"""

from __future__ import annotations

import argparse
import ast
import json
import os
from pathlib import Path
from typing import Any


def literal(node: ast.AST, default: Any = None) -> Any:
  try:
    return ast.literal_eval(node)
  except Exception:
    return default


def command_title(command_id: str) -> str:
  special = {
    "codex-runtime": "Codex Runtime",
    "reload-mcp": "Reload MCP",
    "reload-skills": "Reload Skills",
    "whoami": "Whoami",
    "sethome": "Set Home",
    "yolo": "Yolo",
  }
  if command_id in special:
    return special[command_id]
  return " ".join(part[:1].upper() + part[1:] for part in command_id.replace("_", "-").split("-") if part)


def parse_command_call(call: ast.Call) -> dict[str, Any] | None:
  positional = [literal(arg) for arg in call.args]
  keywords = {keyword.arg: literal(keyword.value) for keyword in call.keywords if keyword.arg}
  name = keywords.get("name") or (positional[0] if len(positional) > 0 else None)
  description = keywords.get("description") or (positional[1] if len(positional) > 1 else "")
  category = keywords.get("category") or (positional[2] if len(positional) > 2 else "Other")
  if not isinstance(name, str) or not name:
    return None

  aliases = keywords.get("aliases", ())
  subcommands = keywords.get("subcommands", ())
  args_hint = keywords.get("args_hint", "")
  cli_only = bool(keywords.get("cli_only", False))
  gateway_only = bool(keywords.get("gateway_only", False))
  gateway_config_gate = keywords.get("gateway_config_gate")

  detail = str(description or "").strip()
  if args_hint:
    detail = f"{detail} (usage: /{name} {args_hint})".strip()
  return {
    "id": name,
    "title": command_title(name),
    "detail": detail,
    "category": str(category or "Other"),
    "aliases": list(aliases or ()),
    "argsHint": str(args_hint or ""),
    "subcommands": list(subcommands or ()),
    "cliOnly": cli_only,
    "gatewayOnly": gateway_only,
    "gatewayConfigGate": gateway_config_gate if isinstance(gateway_config_gate, str) else None,
  }


def registry_node(module: ast.Module) -> ast.AST:
  for node in ast.walk(module):
    if isinstance(node, ast.Assign):
      for target in node.targets:
        if isinstance(target, ast.Name) and target.id == "COMMAND_REGISTRY":
          return node.value
    if isinstance(node, ast.AnnAssign) and isinstance(node.target, ast.Name) and node.target.id == "COMMAND_REGISTRY":
      return node.value
  raise RuntimeError("COMMAND_REGISTRY not found")


def export_commands(hermes_path: Path) -> dict[str, Any]:
  commands_path = hermes_path / "hermes_cli" / "commands.py"
  if not commands_path.exists():
    raise FileNotFoundError(f"Hermes commands.py not found: {commands_path}")
  module = ast.parse(commands_path.read_text(encoding="utf-8"))
  node = registry_node(module)
  if not isinstance(node, ast.List):
    raise RuntimeError("COMMAND_REGISTRY is not a list")
  commands = []
  seen: set[str] = set()
  for element in node.elts:
    if not isinstance(element, ast.Call):
      continue
    command = parse_command_call(element)
    if not command or command["id"] in seen:
      continue
    seen.add(command["id"])
    commands.append(command)
  if not commands:
    raise RuntimeError("No Hermes commands exported")
  return {
    "source": str(commands_path.relative_to(hermes_path)),
    "commands": commands,
  }


def default_hermes_path() -> Path:
  candidates = [
    os.environ.get("HERMES_PATH"),
    str(Path.home() / ".hermes" / "hermes-agent"),
  ]
  for candidate in candidates:
    if candidate and (Path(candidate) / "hermes_cli" / "commands.py").exists():
      return Path(candidate)
  return Path(candidates[-1])


def main() -> int:
  parser = argparse.ArgumentParser(description="Export Hermes COMMAND_REGISTRY to JSON.")
  parser.add_argument("--hermes-path", default=str(default_hermes_path()))
  parser.add_argument("--output", required=True)
  args = parser.parse_args()

  payload = export_commands(Path(args.hermes_path).expanduser())
  output = Path(args.output).expanduser()
  output.parent.mkdir(parents=True, exist_ok=True)
  output.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
  print(f"Exported {len(payload['commands'])} Hermes commands to {output}")
  return 0


if __name__ == "__main__":
  raise SystemExit(main())
