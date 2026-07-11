# Integrations

## MCP

MCP is the main integration surface. It works across agent clients without building one-off adapters.

Recommended config:

```json
{
  "mcpServers": {
    "jobmaxxing": {
      "command": "npm",
      "args": ["run", "mcp"],
      "cwd": "<repository-root>"
    }
  }
}
```

Use this from Cursor, OpenCode, Codex-compatible clients, or Hermes if the client supports stdio MCP servers.

Current MCP tools:

- `jobmaxxing_status`: read the local profile, jobs, companies, connectors, and next actions.
- `jobmaxxing_hermes_status`: read Hermes settings, connector availability, model-route intent, and required Jobmaxxing tools.
- `jobmaxxing_market_research`: read the intelligence catalog.
- `jobmaxxing_automation_plan`: read one deterministic-plus-agent playbook.
- `jobmaxxing_add_job`: mutate the local ledger by adding a scored job and synchronizing its company profile.
- `jobmaxxing_draft_application`: mutate the local ledger by storing submitted-material context on the company profile for a saved job.
- `jobmaxxing_interview_pack`: prepare an interview pack for a saved job.
- `jobmaxxing_company_profiles`: read saved company profiles, application history, submitted material, people maps, source URLs, and research status.
- `jobmaxxing_company_research_packet`: mutate one company profile by preparing an agent-ready research packet.
- `jobmaxxing_browser_plan`: build a consent-gated browser handoff plan; it does not submit applications.
- `jobmaxxing_log_activity`: mutate the local ledger by appending an auditable event.
- `jobmaxxing_audit_text`: audit writing against the saved writing rules and evidence.
- `jobmaxxing_style_prompt`: read the current writing prompt and voice memory.
- `jobmaxxing_company_research_prompt`: read a fact-vs-assumption company research prompt for a saved job.
- `jobmaxxing_command`: route natural-language job-search commands into workflow hints.

## CLI

The CLI mirrors the MCP intent:

```bash
npm run jm -- status
npm run jm -- add-job --company "Kestrel Health Systems" --role "AI Workflow Engineer" --description "Build internal workflow agents."
npm run jm -- browser-plan --request "Prepare application" --source-url "https://company.example/careers/role"
```

## Hermes

Do not fork or vendor Hermes. Keep Hermes as an external local client so it can update on its own, then install the Jobmaxxing overlay on top.

Recommended flow:

1. Keep Hermes in the installed CLI project at `~/.hermes/hermes-agent`.
2. Run `scripts/install_hermes_layer.sh --install`.
3. Let Hermes call Jobmaxxing tools through MCP.
4. Start Hermes with `jobmaxxing_status` and `jobmaxxing_hermes_status`.
5. Keep all Jobmaxxing-specific hiring logic in this repo.

Update flow:

```bash
scripts/hermes_update.sh
```

This is the command behind the Jobmaxxing Hermes update path. It runs the installed Hermes updater, then reinstalls the Jobmaxxing overlay. Direct git fast-forward behavior belongs to the Hermes updater or to `scripts/install_hermes_layer.sh --update`, not to `scripts/hermes_update.sh` itself.

The layer installs:

- `jobmaxxing-orchestrator` skill
- Jobmaxxing system prompt
- focused toolset manifest
- slash update command
- MCP config guidance

See [hermes-layer.md](hermes-layer.md).

## Telegram

Telegram is opt-in. Store no bot token in the local ledger. Jobmaxxing does not poll Telegram while the connector is paused, and a token/chat ID alone is not consent to sync. Enable Telegram in Settings, then use the explicit sync action.

Recommended variables:

```bash
JOBMAXXING_TELEGRAM_BOT_TOKEN=...
JOBMAXXING_TELEGRAM_CHAT_ID=...
```

The current app records notification intent locally. Sending can be added behind the same approval model.

## WhatsApp

WhatsApp is a local-only connector. The native app detects the readable desktop database at:

```text
~/Library/Group Containers/group.net.whatsapp.WhatsApp.shared/ChatStorage.sqlite
```

Search uses contact metadata only. Thread messages are read only after the user saves a person or contact and grants one WhatsApp thread to that person. Imported intelligence is stored locally on the linked contact/person as relationship notes, style summaries, phone/display metadata, message counts, source database path, draft variants, and readable message text for that approved thread. WhatsApp context may support relationship notes and draft replies for that person only. It is not public company evidence, and it must not support application claims unless the user explicitly promotes a reviewed fact to evidence. WhatsApp drafts are never sent automatically.

Local documents follow the same proof boundary. Importing a document stores a local copy and extracted text for review. A document supports application writing only after the user promotes it to evidence, which creates a file-backed evidence item with a local source link.

## Model Tiers

Jobmaxxing separates work by cost and risk:

- cheap drafts: low-risk summaries and keyword extraction
- standard writing: cover letters, outreach, screening answers
- final review: final claim audit, important outreach, and interview narratives

The app exposes three model tiers: Light, Medium, and High. Light defaults to OpenCode Go `deepseek-v4-flash`; Medium and High default to OpenAI routes and can use Grok when the xAI connector is ready. High is the intended Hermes review route for important hiring work when the connector is configured. OpenAI and xAI refresh the models available to the authenticated account through `/v1/models`. OpenCode Go and OpenCode Zen are separate providers; configure either in OpenCode with `/connect`, then refresh its catalog in Settings > Models. The app stores model IDs and named environment-variable references, not API keys. Do not commit secrets.

## Connector Inventory

The native Settings page separates providers from tools:

- Model providers: OpenAI, Grok (xAI), OpenCode Go, OpenCode Zen, Cursor. Provider selection is disabled until the connector is enabled and passes its readiness check.
- Agent tools: local agent layer, Telegram, and WhatsApp.
- Documents and mail: local documents and Apple Mail evidence.

### Grok / xAI

Grok is a first-class model provider. Jobmaxxing marks it connected when any of these are present:

1. `XAI_API_KEY` in the app process environment (same as Hermes `xai` API-key auth)
2. Hermes xAI OAuth or API credentials in `~/.hermes/auth.json` (`xai` / `xai-oauth` from `hermes model`)
3. Grok Build login session in `~/.grok/auth.json` (from `grok login`)

Setup options:

```bash
# API key (console.x.ai)
export XAI_API_KEY="xai-..."

# or Hermes SuperGrok / Premium+ OAuth
hermes model   # choose xAI Grok OAuth

# or Grok Build browser login
grok login
```

Then refresh Connections in Settings. Once ready, any model route can select the xAI provider and a Grok model.

Codex is the runtime/MCP host, not an agent tool connector. Connectors are visible in the native Settings page and returned by `jobmaxxing_hermes_status`.
