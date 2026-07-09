# Native State And Storage Integrity

## Goal

Prevent Jobmaxxing from losing, corrupting, or silently overwriting local job-search state.

## Actual Problem

The app has multiple local state paths with weak failure behavior:

- Native load failures fall back to default state.
- Native save failures only assert in debug.
- TS storage uses a module-local write queue, so API, CLI, MCP, and tests can race across processes.
- Read/status commands can create or rewrite local state.
- Native normalization can drop unknown connectors.
- Generated private artifacts are not ignored.

## Proposed Fix

Be critical of this proposal before implementing it. The simplest correct design is better than a migration framework.

1. Add atomic, durable native saves with explicit user-visible errors.
2. Never replace unreadable existing state with defaults without backup and consent.
3. Add inter-process locking or revision compare-and-retry for `src/lib/storage.ts`.
4. Make status/read paths pure by default.
5. Preserve unknown connector records unless a migration explicitly removes them.
6. Ignore generated private output.
7. Add tests for corrupt JSON, concurrent writes, missing files, and unknown connector preservation.

## Files To Inspect

- `macos/Sources/Jobmaxxing/Stores/JobmaxxingStore.swift`
- `src/lib/storage.ts`
- `src/cli.ts`
- `src/mcp.ts`
- `src/server.ts`
- `src/lib/workflows.ts`
- `.gitignore`
- `output/`

## Acceptance Criteria

- Corrupt native state produces a visible recovery path and a backup.
- Save failures reach the UI.
- API, CLI, and MCP concurrent writes do not drop updates.
- `status` does not create user data unless the command explicitly initializes state.
- Unknown connector records survive load/save normalization.
- Generated private files under `output/` are ignored or moved outside the repo.
- Tests cover the failure modes.

## Tests And Verification

Run:

```bash
npm test
npm run lint
npm run build
npm run smoke
./script/build_and_run.sh --verify
```

Add targeted tests for:

- corrupt store file
- missing store file
- concurrent `updateStore` calls from separate processes
- unknown connector preservation
- native save failure if practical through dependency injection

## Risk Notes

- Do not delete real user state during tests.
- Use temporary stores for destructive test cases.
- Do not commit private `output/` artifacts.
