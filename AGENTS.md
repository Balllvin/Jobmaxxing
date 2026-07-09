# AGENTS.md

This repository is the public, clean source of truth for Jobmaxxing. Treat cleanliness as a product requirement, not a release chore.

## Mandatory First Step

Before creating a branch, committing, pushing, or opening a pull request, set an explicit goal for the work. The goal must include:

- the user-visible change or maintenance outcome
- the files or surfaces expected to change
- the tests and clean-repo checks that will prove it is safe
- the data-safety expectation that no local user state, company scans, credentials, generated output, or private paths enter Git history

Do not commit until the goal is implemented, verified, and the clean-repo check passes.

## Clean Repository Contract

This repository must never contain personal data, private company/application data, local project history, credentials, generated application packs, local logs, build products, dependency folders, or machine-specific paths.

The app must boot as a complete empty shell:

- app code, product defaults, UI, tests, docs, and agent instructions are tracked
- user memory and job-search data are not tracked
- native user state lives under the user's Application Support folder
- web and CLI local state lives in ignored data files unless an explicit test path is provided
- updates add features and migrations without overwriting user state

Run this before every commit:

```bash
npm run clean:check
```

If this fails, fix the repository. Do not bypass the check, weaken the scanner, or add exceptions for real personal data.

## Forbidden Commit Content

Never commit:

- `data/`, `output/`, `dist/`, `macos/dist/`, `macos/.build/`, `node_modules/`, coverage, logs, `.env`, local databases, or imported documents
- access tokens, API keys, cookies, OAuth files, screenshots of private state, resumes, cover letters, PDFs, email exports, or message exports
- real candidate names, real contact names, real company scans, real job applications, real personal evidence, private local project names, private deployment URLs, or absolute local user paths
- old Git history from a local working repo

Use synthetic fixtures for tests. Synthetic fixtures must use clearly fake names, fake domains such as `example.com`, and fake companies that cannot be mistaken for the user's real job-search data.

## Git And GitHub Rules

This clean repository owns the public history. The local private working app is not the public history.

Before a commit:

1. Inspect `git status --short --ignored`.
2. Inspect the diff.
3. Run `npm run clean:check`.
4. Run the relevant test/build commands.
5. Commit only after the tree is clean and verified.

Before updating GitHub `main`:

1. Confirm the local repository has clean root history and does not inherit private history.
2. Confirm no other branch or tag references private history.
3. Push only the sanitized root history.
4. Do not use force-push as a privacy substitute if old public refs still exist. Recreate or purge the public repository when privacy requires zero old traces.

## Setup Commands

- Install dependencies: `npm install`
- Start local app: `npm run dev`
- Run tests: `npm test`
- Run lint: `npm run lint`
- Run build: `npm run build`
- Run strict unused checks: `npm run typecheck:strict`
- Run API smoke checks: `npm run smoke`
- Run native Swift tests: `npm run native:test`
- Run clean-repo gate: `npm run clean:check`
- Run MCP server: `npm run mcp`
- Run CLI: `npm run jm -- status`
- Run native macOS app: `./script/build_and_run.sh`
- Verify native macOS app launch: `./script/build_and_run.sh --verify`
- Install Hermes layer: `scripts/install_hermes_layer.sh --install`
- Check Hermes layer: `scripts/install_hermes_layer.sh --doctor`
- Run Hermes slash update: `scripts/hermes_update.sh`

## Architecture

- Shared domain logic lives in `src/lib/jobmaxxing.ts`.
- Local persistence lives in `src/lib/storage.ts`.
- Native macOS app source lives in `macos/Sources/Jobmaxxing`.
- Hermes overlay files live in `hermes/`.
- Native workflows focus on Dashboard, Chat, Applications, Companies, Contacts, Writing, Interviews, Browser, and Settings.
- UI, API, CLI, and MCP should stay thin wrappers over shared domain behavior.
- Do not store secrets in local state files.
- Do not fork or vendor Hermes. Layer Jobmaxxing on top with `scripts/install_hermes_layer.sh`.
- Keep Hermes tool loading selective: status/style/command always available, workflow tools only when needed.
- Use `jobmaxxing_hermes_status` before changing Hermes tools, connectors, model routes, or slash update behavior.

## Safety

- Never submit job applications automatically.
- Never automate LinkedIn or protected job boards by default.
- Never bypass captchas, rate limits, login controls, or site rules.
- Use browser tools for user-visible preparation and handoff only.
- Keep generated claims traceable to saved evidence.
- Ask for explicit approval before external side effects.

## Writing

Application writing must follow the embedded Amazon-style rules:

- use short sentences
- use subject-verb-object sentences
- replace adjectives with evidence
- remove weasel words
- remove generic AI phrasing
- write for the reader's decision
- distinguish facts from assumptions
- answer only two questions in outreach: interested? done similar work?
- open with interest in the named role, not a generic application phrase
- structure: interest, plain broad work, one specific sample, full-sentence close
- write for HR first; plain English over compressed finance jargon
- prove capability with concrete past work, not empty mapping language
- do not restate the company, paraphrase the posting, or pitch free labor
- sound humble and capable
- stay true to the user; do not reshape the story to over-fit a company

Use `jobmaxxing_audit_text` or `/api/writing/audit` before treating an application draft as ready.

## Code Style

- TypeScript strict mode.
- Prefer small functions with explicit behavior.
- Keep files focused and below sprawling size.
- Use native platform features before adding dependencies.
- Add tests for new branches, parsing, scoring, storage, safety, writing logic, migrations, and clean-repo behavior.
