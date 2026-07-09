# Simplification And Dead Code Removal

## Goal

Remove code that does not serve the current native job-search workflow.

## Actual Problem

The codebase has stale surfaces, duplicate workflows, and hand-maintained layers:

- The React web UI may no longer be a primary product surface.
- Intelligence code and docs remain while native Intelligence was removed.
- Demo/default candidate data lives in production defaults.
- Contacts and Companies duplicate people actions.
- A custom Markdown parser exists while native Markdown is available.
- Hermes slash commands are hand-maintained.
- `CommandRun` remains after Command UI removal.
- DocumentDatabase appears write-only.
- Multiple process runners duplicate behavior.

## Proposed Fix

Be critical of this proposal before deleting anything. First prove whether a surface is used by CLI, MCP, tests, docs, or the packaged app.

1. Build an ownership map for each candidate deletion.
2. Delete stale Intelligence surface if no current workflow needs it.
3. Move demo/default data to fixtures or explicit sample import.
4. Consolidate contact actions under Contacts.
5. Replace custom Markdown parsing with native Markdown if behavior matches.
6. Generate or query Hermes commands instead of maintaining a static list.
7. Remove dead `CommandRun` only after state migration is safe.
8. Remove write-only document index code or wire it to real search.
9. Consolidate process runners behind one small API.

## Files To Inspect

- `src/App.tsx`
- `src/lib/intelligence.ts`
- `macos/Sources/Jobmaxxing/Models/Models.swift`
- `macos/Sources/Jobmaxxing/Stores/JobmaxxingStore.swift`
- `macos/Sources/Jobmaxxing/Views/CompaniesView.swift`
- `macos/Sources/Jobmaxxing/Views/ContactsView.swift`
- `macos/Sources/Jobmaxxing/Views/MarkdownMessageView.swift`
- `macos/Sources/Jobmaxxing/Services/HermesNativeCommandCatalog.swift`
- `macos/Sources/Jobmaxxing/Services/DocumentDatabase.swift`
- `macos/Sources/Jobmaxxing/Support/LocalScriptRunner.swift`
- `macos/Sources/Jobmaxxing/Services/HermesHighAgentRunner.swift`
- `src/lib/seed.ts`
- `src/lib/companies.ts`
- `README.md`
- `docs/intelligence-feature-spec.md`

## Acceptance Criteria

- Deleted code has no live route, test dependency, or documented current workflow.
- Any state model removal includes migration or backward-compatible decoding.
- Demo data is not mixed with real user defaults.
- Markdown rendering still supports needed chat output.
- Hermes commands do not drift from installed Hermes.
- Line count goes down without reducing product capability.

## Tests And Verification

Run:

```bash
npm test
npm run lint
npm run build
npm run smoke
./script/build_and_run.sh --verify
```

Manual checks depend on deleted surface. At minimum, inspect:

- Dashboard.
- Chat.
- Applications.
- Companies.
- Contacts.
- Writing.
- Interviews.
- Browser.
- Settings.

## Risk Notes

- Do not delete a feature only because it is ugly.
- Delete only when the replacement workflow is clearer.
- Prefer one complete deletion over partial hiding.
