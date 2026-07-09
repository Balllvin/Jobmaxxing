# Hermes Layer

Jobmaxxing layers on top of Hermes instead of forking it. Hermes stays updatable. Jobmaxxing owns the hiring workflows, MCP tools, prompts, skills, and local data.

## Install

From a fresh clone:

```bash
scripts/bootstrap_jobmaxxing.sh
```

That installs Node dependencies, configures the Codex MCP server, and installs the Hermes layer.

To install only the Hermes layer:

```bash
scripts/install_hermes_layer.sh --install
```

The installer prefers the Hermes project used by the installed CLI:

```text
~/.hermes/hermes-agent
```

Override it with:

```bash
HERMES_PATH=/path/to/hermes scripts/install_hermes_layer.sh --install
```

If no checkout exists, the installer clones `HERMES_REPO_URL` into `~/.hermes/hermes-agent`.

## What Gets Installed

The installer writes the overlay to:

```text
~/.jobmaxxing/hermes-layer
```

It copies:

- `jobmaxxing.hermes.json`
- `tools/jobmaxxing-toolset.json`
- `prompts/jobmaxxing-system.md`
- `skills/jobmaxxing-orchestrator/SKILL.md`
- `jobmaxxing.env`

The installer does not write into the Hermes checkout. Keep Hermes configured to load `~/.jobmaxxing/hermes-layer` as an external layer or skill path. That keeps `/update` from failing because of Jobmaxxing-generated files inside the Hermes repository.

## Startup Contract

When Hermes starts for Jobmaxxing work, load:

- the Jobmaxxing MCP server: `npm run mcp`
- the system prompt at `~/.jobmaxxing/hermes-layer/prompts/jobmaxxing-system.md`
- the orchestrator skill at `~/.jobmaxxing/hermes-layer/skills/jobmaxxing-orchestrator/SKILL.md`
- the focused toolset at `~/.jobmaxxing/hermes-layer/tools/jobmaxxing-toolset.json`

Hermes should start with:

1. `jobmaxxing_status`
2. `jobmaxxing_hermes_status`
3. only the tools needed for the current workflow

Do not load every connector into context by default.

## Model Route

Hermes should use Jobmaxxing's high route for difficult work when the provider is configured:

```text
final-review -> OpenAI gpt-5.5, reasoning high
```

Use the three app tiers as routing intent: Light for OpenCode Go `deepseek-v4-flash` extraction and low-risk variants, Medium for OpenAI ordinary writing, and High for final review, interview stories, contact messages, claim audits, and high-stakes profile text. Menus should only expose provider/model/reasoning choices that the connector reports as available.

## Slash Update

The Jobmaxxing update command maps to:

```bash
scripts/hermes_update.sh
```

That script:

1. Runs the installed `hermes update` command through `HERMES_BIN` or `hermes` on `PATH`.
2. Reinstalls the Jobmaxxing overlay with `scripts/install_hermes_layer.sh --install`.
3. Leaves Jobmaxxing local state untouched.

The script does not inspect or mutate the Hermes checkout directly. Dirty-check, fetch, fast-forward, backup, and gateway restart behavior belong to the installed Hermes updater.

`scripts/install_hermes_layer.sh --update` is a separate maintenance mode. It performs a bounded git fast-forward of the configured Hermes checkout when that checkout is clean, then reinstalls the overlay. If the git check times out or the checkout is dirty and `HERMES_ALLOW_DIRTY=1` is not set, it skips the fast-forward and reinstalls only the Jobmaxxing layer.

## Native Chat Bridge

The native Chat page keeps one live `hermes chat --cli -Q` process for ordinary messages and Hermes slash commands. Jobmaxxing writes user turns and commands to that official session over stdin and reads stdout with bounded progress polling. It does not run normal chat through `hermes -z`, does not append `/quit` after each command, and does not convert slash commands into prompt text.

For completion detection, Jobmaxxing sends `/status` as a read-only sentinel after ordinary turns and non-status commands. That status output confirms the live Hermes session is idle and keeps session metadata real. `/update` remains separate because it intentionally runs the installed Hermes updater and then reinstalls the Jobmaxxing layer.

## Native Slash Catalog

The native chat composer loads `~/.jobmaxxing/hermes-layer/hermes-commands.json`, exported from `~/.hermes/hermes-agent/hermes_cli/commands.py::COMMAND_REGISTRY`. The Swift fallback exists only for launch resilience. Tests compare the installed JSON to the current local registry when both are present.

Typed slash commands are never rewritten into prompts. If the user types `/version`, `/codex_runtime auto`, `/topic help`, or a future `/new-command`, Jobmaxxing sends that exact text to the live Hermes session and lets Hermes accept or reject it. Autocomplete stays smaller than the full registry: it suggests high-value desktop chat commands and keeps gateway-only or terminal-heavy controls out of the normal palette.

Commands that require session state run in the live Hermes session. Examples include `/queue`, `/yolo`, `/copy`, `/restart`, `/approve`, and `/deny`.

## Parity Map

| Feature | Upstream source | Current Jobmaxxing behavior | Fix status | Remaining gap |
| --- | --- | --- | --- | --- |
| Built-in command registry | `~/.hermes/hermes-agent/hermes_cli/commands.py` | `scripts/export_hermes_commands.py` parses `COMMAND_REGISTRY` and installs `hermes-commands.json`; native Swift loads it with fallback. | Implemented and tested. | Plugin and skill slash commands are accepted when typed as unknown slashes, but they are not exported into native autocomplete yet. |
| Typed slash pass-through | `hermes_cli/commands.py::resolve_command`, `gateway/run.py` slash dispatch | Native chat detects the leading slash, records the command ID for display, and sends the original text unchanged to `hermes chat --cli -Q`. | Implemented and tested for aliases, gateway-only commands, multiline payloads, and unknown future commands. | Desktop autocomplete intentionally suggests only a useful subset. |
| Gateway slash behavior | `gateway/run.py`, `gateway/slash_commands.py`, `gateway/platforms/base.py` | `/queue`, `/steer`, `/approve`, `/deny`, `/goal`, `/moa`, `/version`, `/update`, and other commands flow through the same live Hermes session instead of a Jobmaxxing prompt shim. | Implemented for native pass-through. | Messaging-only command results still depend on Hermes itself because Jobmaxxing is not a messaging gateway. |
| Desktop command surface | `apps/desktop/src/lib/desktop-slash-commands.ts` | Normal chat hides technical registry clutter and generic live-session traces; explicit command output is available under a technical log. | Implemented for the native chat surface. | Jobmaxxing does not reproduce Hermes desktop overlays for model/session/theme pickers; it keeps native app controls separate. |
| Update path | `hermes_cli/cli_commands_mixin.py::_handle_update_command`, `hermes_cli/subcommands/update.py` | `/update` runs `scripts/hermes_update.sh`, which calls installed `hermes update` and then reinstalls the Jobmaxxing layer/export. | Implemented and tested. | Hermes-managed-install restrictions are surfaced by the upstream updater output. |
| Jobmaxxing skills and tags | `hermes/skills/jobmaxxing-orchestrator/SKILL.md`, `hermes/tools/jobmaxxing-toolset.json` | Jobmaxxing exposes hiring workflow tags (`$company`, `$contact`, `@gmail`, local docs) separately from official Hermes slash commands. | Implemented. | These tags are native Jobmaxxing metadata, not upstream Hermes slash commands. |

## Tool Policy

Always available:

- `jobmaxxing_status`
- `jobmaxxing_hermes_status`
- `jobmaxxing_command`
- `jobmaxxing_style_prompt`

Load when needed:

- Applications: `jobmaxxing_add_job`, `jobmaxxing_draft_application`, `jobmaxxing_audit_text`, `jobmaxxing_log_activity`
- Interviews: `jobmaxxing_interview_pack`, `jobmaxxing_company_research_prompt`
- Intelligence: `jobmaxxing_market_research`, `jobmaxxing_automation_plan`
- Browser: `jobmaxxing_browser_plan`, `jobmaxxing_log_activity`
- Documents: local document import/evidence tools, Google Drive, Gmail when authorized
- Repo proof: GitHub and filesystem when the user asks for project proof
- Work tracking: Linear when the user wants task tracking
- Delegation: subagents when work splits cleanly

Blocked by default:

- external submit
- LinkedIn message send
- profile edit
- captcha bypass

## Connector Reflection

The native Settings page separates providers from tools:

- Model providers: OpenAI, Grok (xAI), OpenCode Go, Cursor.
- Agent tools: local agent layer, Telegram, and WhatsApp.
- Documents and mail: local documents and Apple Mail evidence.

Codex remains the MCP runtime host, not an agent tool connector.
This makes connector state visible in the app and available to agents through `jobmaxxing_hermes_status`.

Telegram sync is explicit. The native Chat page does not poll Telegram on a timer or on page open; it only syncs when the user asks for that connector work and the bot token reference plus chat ID are configured.

## Documents

Imported files are copied into:

```text
Application Support/Jobmaxxing/Documents
```

Document metadata and extracted text are indexed in:

```text
Application Support/Jobmaxxing/documents.sqlite
```

Hermes should link documents by title, path, or evidence id. It should not paste entire documents into prompts unless the specific task requires full text.
