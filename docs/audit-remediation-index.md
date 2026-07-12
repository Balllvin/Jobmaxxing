# Jobmaxxing Audit Remediation Index

This document splits the audit findings into focused repair threads. Each thread is small enough for one Codex thread to own, but broad enough to fix a real product problem instead of one symptom.

Do not treat the proposed fixes as instructions to implement blindly. Each thread must read the named files, verify the failure, challenge the proposed approach, then ship the simplest fix that preserves the product goal: help users get a job with truthful, high-signal, user-approved hiring work.

## Operating Rules

- No automatic job submissions.
- No hidden external side effects.
- No fake agent status.
- No generated claims without saved evidence.
- No broad rewrites unless they remove real complexity.
- Keep UI smaller, clearer, and closer to the hiring workflow.
- Use short sentences in user-facing writing.
- Use subject-verb-object sentences.
- Replace adjectives with evidence.
- Distinguish facts from assumptions.
- Run tests before claiming success.

## Levels

### Level 0: Trust And Data Safety

Fix these first. They can lose local state, mislead the user, or leak private job-search data.

1. [Native State And Storage Integrity](audit-threads/data-integrity-and-storage.md)
2. [Hermes Native Session Revamp](audit-threads/hermes-native-session.md)
3. [Evidence, Writing, And Claim Safety](audit-threads/evidence-writing-safety.md)

### Level 1: Product Workflow Clarity

Fix these after Level 0, because they make the app harder to operate and hide what actually happened.

4. [Native Workflow And UI Simplification](audit-threads/native-workflow-ui.md)
5. [Connector And External Action Honesty](audit-threads/connectors-and-external-actions.md)

### Level 2: Codebase Reduction

Fix these once core behavior is trustworthy. The goal is less code, fewer duplicate surfaces, and fewer stale promises.

6. [Simplification And Dead Code Removal](audit-threads/simplification-and-dead-code.md)
7. [Performance And Scale Hygiene](audit-threads/performance-and-scale.md)

### Level 3: Documentation And Validation

Fix these to keep future work honest.

8. [Docs, Tests, And Validation Contracts](audit-threads/docs-tests-and-validation.md)

## Cross-Thread Bugs To Preserve

The attached chat screenshot adds a concrete Hermes bug:

- The user message renders as a huge right-aligned text block over the transcript instead of a contained chat row.
- The assistant response and user prompt overlap visually.
- The transcript shows stale session metadata, including stale activity, zero tokens, and no running agent despite a recent response.
- `/yolo` is blocked because Jobmaxxing does not own a live Hermes session.
- The UI tells the user to use Hermes elsewhere instead of making the native app the real operator surface.

This belongs primarily to the Hermes thread, but the UI thread should also verify the final transcript layout.

## Suggested Thread Boundaries

| Thread | Safe Scope | Do Not Include |
| --- | --- | --- |
| Hermes session revamp | Native chat, Hermes runner, layer install/update contract, slash command handling, transcript rendering | Storage locking, writing audit, unrelated UI pages |
| Data integrity | Native state load/save, TS store locking, pure reads, output privacy | Hermes live-session implementation |
| Evidence and writing | Draft generation, writing audit, claim scoring, WhatsApp/document evidence policy | General layout cleanup |
| Native UI workflow | Dashboard, Applications, Companies, Contacts, Writing, Interviews, Browser, Settings layout and navigation | Agent runtime rewrite |
| Connectors | Provider status, connector truth, Telegram/WhatsApp external actions, URL validation | Full storage migration |
| Simplification | Dead code, stale Intelligence surface, duplicate UI, custom markdown parser, command catalog, demo defaults | Behavior changes without tests |
| Performance | Full-store payloads, repeated normalization, main-thread process/script checks | User-facing copy rewrites |
| Docs and tests | README/docs parity, native tests, Hermes parity, validation scripts | Product behavior changes beyond test wiring |

## Shared Validation

Every thread should run the smallest relevant set first, then the full set when behavior changes:

```bash
npm test
npm run lint
npm run build
npm run smoke
./script/build_and_run.sh --verify
```

Threads that touch native UI must relaunch the packaged app and inspect the real UI. Build success is not enough.

Threads that touch Hermes must verify:

- normal message send
- slash command behavior
- `/update`
- a persistent-session command such as `/yolo`
- visible progress
- copy and reply controls
- Telegram behavior only when explicitly configured

Threads that touch writing must verify `jobmaxxing_audit_text` and the native Writing page against weak drafts, unsupported claims, and evidence-backed drafts.

Threads that touch local state must verify no source files, generated private output, or local user data are committed by accident.
