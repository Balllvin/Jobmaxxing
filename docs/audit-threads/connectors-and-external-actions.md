# Connector And External Action Honesty

## Goal

Make every connector, model provider, URL opener, and external action truthful and permissioned.

## Actual Problem

The app currently blurs available, configured, and actually usable states:

- OpenAI can appear connected without a verified key or session.
- Cursor can appear in conflicting states.
- Telegram can poll from Chat without a clear user action.
- WhatsApp local imports can persist raw messages while docs imply otherwise.
- URL openers accept arbitrary strings and may no-op or open unsafe targets.
- Settings script controls can freeze or mislead the main app.

## Proposed Fix

Be critical of this proposal before implementing it. Do not add connector ceremony unless it reduces confusion.

1. Define connector states: unavailable, installed, configured, authorized, tested, failed.
2. Show only states the app can prove.
3. Make Telegram sync explicit unless the user enables polling.
4. Make WhatsApp import permissioned and transparent about stored fields.
5. Validate URLs before storing and before opening.
6. Surface no-op and failed open actions to the user.
7. Run script controls asynchronously with cancellable progress and clear results.

## Files To Inspect

- `macos/Sources/Jobmaxxing/Views/SettingsView.swift`
- `macos/Sources/Jobmaxxing/Stores/JobmaxxingStore.swift`
- `macos/Sources/Jobmaxxing/Support/LocalScriptRunner.swift`
- `macos/Sources/Jobmaxxing/Services/WhatsAppLocalStore.swift`
- `macos/Sources/Jobmaxxing/Views/ApplicationsView.swift`
- `macos/Sources/Jobmaxxing/Views/ContactsView.swift`
- `src/lib/contracts.ts`
- `src/lib/companies.ts`
- `docs/integrations.md`
- `docs/safety-policy.md`

## Acceptance Criteria

- Provider status does not claim readiness without verified readiness.
- Connector state is consistent across list and detail.
- Telegram does not poll unless enabled.
- WhatsApp storage behavior is visible before import.
- Invalid URLs are rejected or marked invalid.
- External open failures are visible.
- Script controls cannot freeze the UI.
- Tests cover URL validation and connector normalization.

## Tests And Verification

Run:

```bash
npm test
npm run lint
npm run build
./script/build_and_run.sh --verify
```

Manual native checks:

- Settings provider state.
- Settings connector rows and detail.
- Browser handoff.
- Application source open behavior.
- Contact research URL behavior.
- Telegram disabled state.
- WhatsApp import permission prompt path if available.
