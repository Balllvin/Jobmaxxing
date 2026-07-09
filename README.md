# Jobmaxxing

Jobmaxxing is a local-first job search operating system. Its sole job is to help the user get a job without turning the user into a mass-apply bot.

It gives humans and coding agents one place to:

- run a native macOS workspace with pages for dashboard, chat, applications, companies, contacts, writing, interviews, browser, and settings
- track roles, stages, notes, risks, and application history
- build company profiles with research packets, people maps, source links, application material, and hiring context
- attach local resumes, writing samples, project briefs, and other documents to applications, companies, writing, or chat work
- score jobs against the user's goals and saved evidence
- draft cover letters, outreach, screening answers, and follow-ups
- audit writing for Amazon-style clarity and AI slop
- prepare mock interviews for text, calls, onsites, and panels
- plan browser work with consent gates
- expose the same job-search workflows to Codex-compatible clients, Cursor, OpenCode, and Hermes through MCP or CLI

## Native macOS App

Bootstrap a fresh clone:

```bash
scripts/bootstrap_jobmaxxing.sh
```

Run the desktop app:

```bash
./script/build_and_run.sh
```

Verify build and launch:

```bash
./script/build_and_run.sh --verify
```

The native app lives in `macos/` and builds to `macos/dist/Jobmaxxing.app`. It uses local app-support JSON for desktop state, indexes imported document metadata/text in `documents.sqlite`, and keeps imported files under the user's Application Support folder.

The Codex app Run action is wired through `.codex/environments/environment.toml`.

See [docs/native-macos.md](docs/native-macos.md).

## Codex MCP Setup

Install the Jobmaxxing MCP server into local Codex config:

```bash
scripts/install_codex_mcp.sh
```

The installer is idempotent and adds `[mcp_servers.jobmaxxing]` to `~/.codex/config.toml` if it is missing.

## Web/API Setup

```bash
npm install
npm run dev
```

The app runs at:

- Web UI: `http://127.0.0.1:5174`
- API: `http://127.0.0.1:4174`

Useful commands:

```bash
npm test
npm run lint
npm run build
npm run typecheck:strict
npm run smoke
npm run native:test
npm run jm -- status
npm run mcp
```

## Data

The web/API local store is `data/jobmaxxing.json`. Override it when testing:

```bash
JOBMAXXING_DATA_PATH=/tmp/jobmaxxing.json npm run api
```

Secrets do not belong in the store. The native settings page exposes three editable model tiers:

- Light: OpenCode Go `deepseek-v4-flash`
- Medium: OpenAI `gpt-5.5`, reasoning medium
- High: OpenAI `gpt-5.5`, reasoning high

The provider catalog stays small: OpenAI, Grok (xAI), OpenCode Go, and Cursor. Provider menus only allow enabled, connected providers. The Light route uses OpenCode's `low`, `medium`, `high`, and `max` DeepSeek reasoning choices. The OpenAI routes use `none`, `minimal`, `low`, `medium`, `high`, and `xhigh` when the selected model supports them. Grok connects through `XAI_API_KEY`, Hermes xAI OAuth (`hermes model`), or Grok Build login (`grok login` / `~/.grok/auth.json`). Cursor stays unavailable until Cursor Agent is authenticated and returns account models.

## MCP

Run the MCP server:

```bash
npm run mcp
```

Example client config:

```json
{
  "mcpServers": {
    "jobmaxxing": {
      "command": "npm",
      "args": ["run", "mcp"],
      "cwd": "~/Jobmaxxing"
    }
  }
}
```

Tools exposed:

- `jobmaxxing_status`
- `jobmaxxing_hermes_status`
- `jobmaxxing_market_research`
- `jobmaxxing_automation_plan`
- `jobmaxxing_add_job`
- `jobmaxxing_draft_application`
- `jobmaxxing_interview_pack`
- `jobmaxxing_company_profiles`
- `jobmaxxing_company_research_packet`
- `jobmaxxing_browser_plan`
- `jobmaxxing_log_activity`
- `jobmaxxing_audit_text`
- `jobmaxxing_style_prompt`
- `jobmaxxing_company_research_prompt`
- `jobmaxxing_command`

## Browser Policy

Jobmaxxing prepares work. It does not silently submit applications.

Protected sites such as LinkedIn and Indeed default to manual assist:

- prepare copy-ready answers and documents
- let the user control the site
- stop before submission
- log what was proposed and what the user approved

See [docs/safety-policy.md](docs/safety-policy.md).

## Hermes

Hermes is treated as a layered local agent, not vendored code. The default profile points to the installed CLI project:

```text
~/.hermes/hermes-agent
```

Install the layer:

```bash
scripts/install_hermes_layer.sh --install
```

Run the Hermes slash-update equivalent:

```bash
scripts/hermes_update.sh
```

The layer gives Hermes the Jobmaxxing MCP tools, the `jobmaxxing-orchestrator` skill, focused connector guidance, and an update command that runs the installed Hermes updater before reinstalling the overlay. Hermes should use Jobmaxxing's final-review route for high-stakes hiring work when that route is configured.

The native chat composer mirrors a pinned Hermes slash-command catalog. Persistent-session commands such as `/queue`, `/yolo`, `/copy`, and `/restart` are shown as Hermes commands, but the app does not fake them as ordinary prompt text when a live Hermes session is required.

See [docs/hermes-layer.md](docs/hermes-layer.md) and [docs/integrations.md](docs/integrations.md).

## Writing System

Jobmaxxing embeds Amazon-style writing rules and anti-slop checks:

- short sentences
- subject-verb-object structure
- proof over adjectives
- no weasel words
- no generic AI phrasing
- every strong claim maps to saved evidence

See [docs/writing-system.md](docs/writing-system.md).

## Intelligence

The Intelligence catalog is exposed through MCP and command routing, not a separate native page. Agents can call `jobmaxxing_market_research` and `jobmaxxing_automation_plan` to decide what should be scripted, what should be agent-written, and where user approval is required.

See [docs/product-research.md](docs/product-research.md) and [docs/intelligence-feature-spec.md](docs/intelligence-feature-spec.md).
