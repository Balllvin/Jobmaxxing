# Native macOS App

Jobmaxxing's primary user surface is the native macOS app in `macos/`.

## Structure

- `App/`: app entrypoint, commands, settings scene, activation policy
- `Models/`: codable state models
- `Stores/`: local persistence and workflow logic
- `Views/`: desktop pages and shared components
- `Support/`: small extensions, script runners, and repo-root helpers
- `Services/`: local services such as the SQLite document index

The app uses a native sidebar split view. Do not put every workflow on one page.

## Current Sidebar

- Dashboard: queue summary, next actions, and recent activity.
- Chat: Hermes-backed command workspace, dictation, attachments, Telegram sync, trace rows, and slash-command suggestions.
- Applications: role intake, pipeline, selected-role dossier, proof-linked draft pack, and document attachment.
- Companies: company profiles, application history, submitted material, contacts, source maps, and explicit local research plans.
- Contacts: recruiter, referral, WhatsApp, and company-linked relationship context.
- Writing: anti-slop audit, prompt memory, and evidence-backed draft checks.
- Interviews: text/call/onsite/panel practice sessions and follow-up prep.
- Browser: consent-first protected-site handoff plans.
- Settings: setup, code help, account/profile, model providers, agent tools, documents/mail connectors, Hermes layer controls, and browser permissions.

Intelligence and command routing still exist through shared domain logic, MCP tools, and chat suggestions. They are not separate native sidebar pages.

## Interface System

The app uses a warm, neutral Liquid Glass system from `Views/LiquidGlassDesign.swift`:

- bounded native glass surfaces on supported macOS versions
- native material fallback on older systems
- opaque, readable surfaces when Reduce Transparency is enabled
- one shared accent, refractive one-pixel edges, restrained shadows, and adaptive light/dark colors
- 44-point icon targets, immediate press feedback, keyboard focus rings, and Reduce Motion-aware transitions

Keep glass bounded to navigation, editors, composers, and meaningful grouped surfaces. Do not stack material effects across long scrolling regions.

## Run

```bash
./script/build_and_run.sh
```

The script compiles the SwiftUI source directly with `swiftc` and stages `macos/dist/Jobmaxxing.app`. SwiftPM source is still present in `macos/Package.swift`, but this machine's run path uses direct compilation so it does not depend on SwiftPM manifest evaluation.

Run native XCTest targets through SwiftPM when the local Command Line Tools install can evaluate package manifests:

```bash
npm run native:test
```

If that command fails before source compilation with a `PackageDescription` manifest-link error, treat it as a local Swift toolchain issue and use `./script/build_and_run.sh --verify` for packaged app smoke coverage until Command Line Tools are repaired.

## Hermes Controls

The Settings page can:

- show a short setup path for provider, agent layer, profile, proof, and permission setup
- answer exact codebase questions through Code Help, using the Medium route and read-only local repository search
- install the Jobmaxxing Hermes overlay
- run the slash-update script
- run the Hermes doctor check
- configure Light, Medium, and High routes through provider/model menus; refresh each configured provider to load the models available to that account
- show the final-review model route Hermes should use for high-stakes work when configured
- group connector setup for model providers, agent tools, documents/mail, and work tracking

The controls call scripts in the repository through `LocalScriptRunner`. Process-backed setup checks run asynchronously with hard timeouts so connector probes cannot block app launch.

OpenCode Go and OpenCode Zen are separate providers. Configure each in OpenCode with `/connect`, then use the refresh control in Models to load that provider's current catalog. OpenAI and xAI refresh through their authenticated `/v1/models` endpoints. The app stores model IDs and named environment-variable references, not API keys. Secret connector fields reject raw tokens.

## Documents

Imported files are copied into Application Support off the main actor. PDF/text extraction and SQLite indexing run in the same background pipeline; the UI reports loading, partial copy failures, and index failures separately. Metadata and extracted text are indexed in `documents.sqlite`, which lets agents reference documents by id, title, or path without pasting every file into prompt context.
