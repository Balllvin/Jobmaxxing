# Safety Policy

Jobmaxxing is consent-first software.

## Non-Negotiable Rules

- No hidden scraping.
- No fake accounts.
- No captcha bypass.
- No rate-limit bypass.
- No application submission by an agent.
- No protected-site automation by default.
- No generated claims without saved evidence.
- No credentials in prompts, logs, or the local store.
- No arbitrary external URL opens. External web targets must parse as `http` or `https`, and failed opens must be visible.

## Browser Modes

### Manual Only

The agent prepares materials and the user operates the site. This is the default mode for LinkedIn, Indeed, Glassdoor, ZipRecruiter, and similar sites.

### Assist Fill

The agent may prepare field values or copy text into user-visible fields on lower-risk sites. The user still reviews and submits manually.

### Autonomous Prepare

The agent may search public pages, build a job record, and stage materials locally. It still cannot submit applications or perform external side effects.

## Approval Levels

- Read: local read-only work.
- Draft: generate local artifacts with provenance.
- Stage: create a pending action with preview and risk.
- Execute: requires explicit user action.
- Admin: requires user-controlled setup outside the agent.

## Protected Sites

Public research found that LinkedIn and Indeed restrict third-party scraping and automation in their terms/help pages. Jobmaxxing therefore treats those as manual-assist surfaces:

- LinkedIn automated activity help: https://www.linkedin.com/help/linkedin/answer/a1340567
- LinkedIn prohibited software help: https://www.linkedin.com/help/linkedin/answer/a1341387
- Indeed legal terms: https://www.indeed.com/legal

## Audit Log

Every agent-visible action should be logged with:

- actor
- action type
- target job
- summary
- approval state
- sequence number

The ledger is for accountability, not surveillance.

## Local Communication Data

WhatsApp and Telegram are permissioned connectors. Telegram sync requires the connector to be enabled and an explicit sync action. WhatsApp search reads local contact metadata; importing a chosen thread stores readable message text locally on the linked contact for draft-only context. Jobmaxxing never sends WhatsApp or Telegram messages automatically.
