# Hermes Native Session Revamp

## Goal

Make the Jobmaxxing Chat page work like Hermes intends, with Jobmaxxing skills layered into Hermes instead of Jobmaxxing pretending to be Hermes.

The user should be able to stay in Jobmaxxing, use Hermes-native commands, see useful progress, and keep job-search context grounded in MCP tools and saved evidence.

## Actual Problem

Jobmaxxing currently wraps Hermes through one-shot and disposable CLI calls:

- `macos/Sources/Jobmaxxing/Services/HermesHighAgentRunner.swift` runs `hermes -z` for normal messages.
- The same runner runs `hermes chat --cli -Q` for some slash commands, then quits.
- Persistent session commands are blocked because there is no live Hermes session.
- `macos/Sources/Jobmaxxing/Stores/JobmaxxingStore.swift` owns a separate chat transcript.
- `macos/Sources/Jobmaxxing/Views/HermesChatView.swift` suggests slash commands, skills, and plugins even when the native bridge cannot execute them.
- `macos/Sources/Jobmaxxing/Services/HermesNativeCommandCatalog.swift` hand-maintains a command catalog that can drift from Hermes.

The attached screenshot proves the product failure:

- Long user messages render as a giant right-aligned block.
- The user prompt visually overlaps the assistant transcript.
- The app shows stale session metadata.
- `/yolo` is blocked with a message that tells the user to leave the app.
- The chat surface exposes implementation failure instead of acting as the operator surface.

## Root Cause

Jobmaxxing does not own or embed a Hermes session. It owns a parallel transcript and uses Hermes as a subprocess formatter. That breaks Hermes semantics for stateful slash commands, token state, long-running work, updates, and Telegram-style progress.

## Proposed Fix

Be critical of this proposal before implementing it. Confirm how Hermes currently exposes a UI, TUI, session state, streaming events, logs, or Telegram bridge. Copy the official Hermes interaction model where possible. Do not invent another harness if Hermes already has one.

Preferred direction:

1. Treat Hermes as the session owner.
2. Keep Jobmaxxing as a Hermes layer: MCP tools, skills, system prompt, and job-search state.
3. Replace one-shot `hermes -z` chat with a persistent Hermes session bridge.
4. Render Hermes events in the native Chat page with a thin Jobmaxxing theme.
5. Remove the hand-maintained command catalog if Hermes can expose commands dynamically.
6. Run slash commands through Hermes, including persistent-session commands.
7. Show progress the way Hermes shows it in Telegram or its own UI.
8. Keep external delivery opt-in.

Fallback direction:

If Hermes does not expose a stable embeddable interface, build the smallest bridge around the official CLI/TUI/session files. The bridge should still preserve one live session and should not parse terminal art when a structured state source exists.

## Files To Inspect

- `macos/Sources/Jobmaxxing/Views/HermesChatView.swift`
- `macos/Sources/Jobmaxxing/Views/HermesChatRows.swift`
- `macos/Sources/Jobmaxxing/Views/HermesComposerTextView.swift`
- `macos/Sources/Jobmaxxing/Services/HermesHighAgentRunner.swift`
- `macos/Sources/Jobmaxxing/Services/HermesNativeCommandCatalog.swift`
- `macos/Sources/Jobmaxxing/Stores/JobmaxxingStore.swift`
- `scripts/install_hermes_layer.sh`
- `scripts/hermes_update.sh`
- `docs/hermes-layer.md`
- `hermes/jobmaxxing.hermes.json`
- `hermes/prompts/jobmaxxing-system.md`
- `hermes/skills/jobmaxxing-orchestrator/SKILL.md`

## Acceptance Criteria

- Normal chat uses the same live Hermes session across turns.
- Persistent slash commands work inside Jobmaxxing when Hermes supports them.
- `/yolo` does not become prompt text.
- `/yolo` is not blocked just because Jobmaxxing used a disposable process.
- `/update` uses the official Hermes update flow.
- The Jobmaxxing layer loads as external skills, prompts, and MCP tools.
- The chat transcript does not overlap at narrow or wide window sizes.
- Long user messages wrap inside a readable row with a sane max width.
- Progress is visible but compact.
- Thinking/tool traces are useful and do not flood the transcript.
- Token, activity, and running state reflect the live Hermes session or are removed.
- Telegram sync never runs silently unless the user enabled it.
- The app does not tell the user to leave Jobmaxxing for normal Hermes work.

## Tests And Verification

Run:

```bash
npm test
npm run lint
npm run build
./script/build_and_run.sh --verify
```

Manual native checks:

- Send a normal message.
- Send a long message like the screenshot.
- Run `/status`.
- Run `/yolo` or another persistent-session command.
- Run `/update` only after confirming it is safe in the local checkout.
- Copy an assistant reply.
- Reply to a user and assistant message.
- Attach a file.
- Resize the app narrow and wide.
- Confirm Telegram does nothing when not configured.

## Risk Notes

- Do not fork or vendor Hermes.
- Do not fake a live session.
- Do not hardcode command lists if Hermes can provide them.
- Do not persist raw thinking if Hermes treats it as transient UI state.
- Do not expose private local paths unless the user needs them.
