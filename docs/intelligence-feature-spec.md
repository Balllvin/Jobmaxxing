# Intelligence Feature Spec

## Problem Statement

Job seekers do not only need more applications. They need to know which sources are worth using, which workflows can be automated safely, where their evidence is weak, and when AI-generated volume will hurt them. Current tools split this across job boards, trackers, resume scanners, autofill extensions, and auto-apply agents.

The cost of not solving this is wasted time, duplicate applications, generic writing, unsafe browser automation, and a job-search strategy the user cannot inspect or improve.

## Goals

- Reduce low-fit applications by making source choice and playbook choice explicit before drafting.
- Make agent work auditable by showing deterministic steps, agent steps, outputs, and safety gates.
- Help the user compare job boards, ATS flows, and competitor patterns through chat, MCP, or command routing.
- Route Codex-compatible clients, the local agent layer, Cursor, and OpenCode through the same source intelligence.
- Improve weekly learning by tracking which source/playbook choices create replies and interviews.

## Non-Goals

- Do not silently submit applications. The app prepares and logs work; the user controls final submission.
- Do not bypass protected sites, captchas, rate limits, or account rules.
- Do not optimize for raw application volume as the main success metric.
- Do not treat ATS keyword match as proof of fit.
- Do not require every connector to be configured before the intelligence catalog is useful.

## User Stories

- As a job seeker, I want to compare job boards and ATS sources so that I choose the highest-signal workflow for each role.
- As a job seeker, I want to see what should be scripted and what should be agent-written so that I can trust the automation.
- As a job seeker, I want to route a source or playbook through chat or MCP so that Codex or Hermes can act on it immediately.
- As a job seeker, I want to see competitor patterns and market complaints so that Jobmaxxing avoids becoming another spammy auto-apply tool.
- As an agent, I want a compact market research tool so that I can select workflows without loading unrelated docs or connectors.

## Requirements

### Must-Have

- Shared intelligence catalog available through MCP, command routing, and the native chat workflow.
- Shared MCP-accessible market catalog with competitor apps, job-board sources, automation playbooks, complaints, and opportunities.
- `jobmaxxing_market_research` tool that returns the catalog to agents.
- `jobmaxxing_automation_plan` tool that returns one playbook by id or goal.
- Command routing for market, competitor, source, job board, playbook, and feature requests.
- Playbooks for source trust, evidence coverage, application-pack diffs, contact cadence, and interview transcript review.
- Hermes toolset bucket that loads intelligence tools only when needed.
- Tests for command routing, catalog integrity, and playbook selection.

### Nice-to-Have

- Job-scoped sourced company/person brief stored on each role.
- Source ROI metrics from reply rates, interview rates, and stale follow-ups.
- Job-scoped contact ledger for recruiters, founders, referrals, and follow-up state.
- Saved search templates for target roles and locations.
- ATS field-kit export for copy-ready application answers.

### Future Considerations

- Browser extension bridge for structured field extraction.
- Optional Gmail reconciliation for recruiter replies and follow-up status.
- Optional Google Drive import for resume versions and writing samples.
- Optional GitHub proof mining for shipped project links.
- Strict prep-only interview mode that critiques practice transcripts but refuses stealth live-answer assistance.

## Success Metrics

- A command about competitors or job boards routes to intelligence tools.
- A user can route a source or playbook through the native chat workflow or MCP without inventing a separate tracker.
- Every playbook includes deterministic steps, agent steps, safety checks, and outputs.
- Protected-site workflows keep manual-submit gates visible.
- Application drafts continue to trace strong claims to saved evidence.

## Open Questions

- Engineering: Should job-scoped research briefs live directly on `JobRecord` or in a separate local research table?
- Product: Which source outcomes should count most: reply, screen, onsite, offer, or user-rated quality?
- Design: Should source ROI appear on Dashboard or Companies once enough activity is logged?
- Safety: Which sites need stronger default restrictions beyond LinkedIn and Indeed?
