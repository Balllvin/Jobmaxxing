# Performance And Scale Hygiene

## Goal

Keep Jobmaxxing responsive as local state, documents, contacts, applications, and chat history grow.

## Actual Problem

The app does unnecessary broad work:

- API and MCP routes return full-store payloads.
- Store reads clone and normalize large graphs repeatedly.
- Native settings and script checks can block or feel synchronous.
- Chat persists broad transcript state.
- Document indexing can fail silently, which hides performance and correctness problems.
- Large SwiftUI files make performance work hard to reason about.

## Proposed Fix

Be critical of this proposal before implementing it. Measure first when practical.

1. Add focused read APIs for common UI and MCP calls.
2. Avoid returning full store from mutation routes unless callers need it.
3. Cache or memoize derived contact/company indexes where safe.
4. Move slow script checks off the main UI path.
5. Keep chat transcript storage bounded or summarized when Hermes owns history.
6. Surface document-index timing and failures.
7. Split large files only where it reduces cognitive load and compile/test risk.

## Files To Inspect

- `src/server.ts`
- `src/mcp.ts`
- `src/lib/storage.ts`
- `src/lib/companies.ts`
- `src/lib/jobmaxxing.ts`
- `macos/Sources/Jobmaxxing/Stores/JobmaxxingStore.swift`
- `macos/Sources/Jobmaxxing/Views/SettingsView.swift`
- `macos/Sources/Jobmaxxing/Support/LocalScriptRunner.swift`
- `macos/Sources/Jobmaxxing/Services/DocumentDatabase.swift`

## Acceptance Criteria

- Common status calls do not serialize the full store.
- Mutating API/MCP calls return concise results unless full state is requested.
- Repeated company/contact lookup avoids obvious repeated scans.
- Slow runtime checks show progress and do not freeze the app.
- Document-index failures include timing and error details.
- Performance tests or smoke checks cover large local state fixtures.

## Tests And Verification

Run:

```bash
npm test
npm run lint
npm run build
npm run smoke
./script/build_and_run.sh --verify
```

Add focused checks for:

- large store status response size
- repeated company lookup cost
- large chat transcript rendering
- settings runtime check responsiveness

## Risk Notes

- Do not optimize by hiding useful data.
- Do not add heavy caching that can go stale.
- Do not split files without improving boundaries.

## Remediation Notes

- `/api/state`, `/api/status`, and `jobmaxxing_status` return compact status summaries by default. Full local state is still available through `/api/export` or explicit `include=store` / `full=1` API requests.
- Mutating API and MCP workflows return concise mutation results unless the caller explicitly asks for the full store.
- Company and contact normalization use request-local indexes instead of repeated graph scans; no long-lived cache is used.
- Native settings scripts run asynchronously with progress text and bounded execution.
- Hermes local transcript persistence is capped to the latest native display messages so Hermes can own longer history without growing Jobmaxxing state indefinitely.
- Document imports cap extracted text work and record document index success, duration, and failure detail in app state.
