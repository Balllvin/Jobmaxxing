# Evidence, Writing, And Claim Safety

## Goal

Make every generated application claim traceable, concise, and useful to a hiring decision.

## Actual Problem

Writing and evidence flows currently overtrust weak context:

- Evidence selection can choose zero-relevance facts.
- Draft templates can add unsupported generic claims.
- Writing audit passes weak drafts.
- Native and TS writing audits do not enforce the same rules.
- WhatsApp and document evidence policy is unclear.
- MCP descriptions understate when tools mutate state.

## Proposed Fix

Be critical of this proposal before implementing it. The fix should improve hiring truth, not just add more lint words.

1. Require evidence relevance thresholds before using a fact in a draft.
2. Separate facts, assumptions, and missing evidence in draft output.
3. Replace generic claims with proof-backed statements or remove them.
4. Make native and TS writing audits share the same rule source.
5. Add hard failures for unsupported claims in final-ready drafts.
6. Update MCP tool descriptions so mutating tools say what they mutate.
7. Clarify WhatsApp and document persistence in product docs and UI.

## Files To Inspect

- `src/lib/jobmaxxing.ts`
- `src/lib/workflows.ts`
- `src/mcp.ts`
- `macos/Sources/Jobmaxxing/Stores/JobmaxxingStore.swift`
- `macos/Sources/Jobmaxxing/Views/WritingView.swift`
- `docs/writing-system.md`
- `docs/integrations.md`
- `macos/Sources/Jobmaxxing/Services/WhatsAppLocalStore.swift`
- `macos/Sources/Jobmaxxing/Models/Models.swift`

## Acceptance Criteria

- A weak draft with generic excitement does not score as ready.
- A draft with unsupported claims identifies each unsupported claim.
- A draft with saved evidence can pass.
- Draft generation does not use zero-relevance evidence.
- WhatsApp evidence handling is explicit and permissioned.
- MCP tool descriptions disclose local state changes.
- Tests cover weak drafts, evidence-backed drafts, unsupported claims, and no-evidence roles.

## Writing Rules

Use these in prompts, docs, and generated output:

- Use short sentences.
- Use subject-verb-object sentences.
- Name the proof.
- Link or cite saved evidence when available.
- Remove generic excitement.
- Remove inflated praise.
- Remove unsupported claims.
- Write for the reader's decision.
- Mark assumptions as assumptions.

## Tests And Verification

Run:

```bash
npm test
npm run lint
npm run build
./script/build_and_run.sh --verify
```

Manual native checks:

- Open Writing.
- Audit a weak draft.
- Audit an evidence-backed draft.
- Generate an application pack with no matching evidence.
- Confirm the UI blocks or labels unsupported claims.
