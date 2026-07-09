# Docs, Tests, And Validation Contracts

## Goal

Make the repo describe the product that actually exists and make regressions hard to ship.

## Actual Problem

Docs and validation have drifted:

- README and native docs mention removed or shifted surfaces.
- Hermes docs overclaim model routing and update behavior.
- Integration docs understate WhatsApp storage.
- MCP docs omit current company tools and mutation behavior.
- Native tests are not clearly wired into the standard validation path.
- Hermes command parity is conditional.
- Strict unused checks catch at least one issue not covered by normal lint.

## Proposed Fix

Be critical of this proposal before implementing it. Documentation should shrink when product behavior becomes simpler.

1. Update docs after behavior fixes, not before.
2. Remove stale surface descriptions.
3. Make Hermes docs match the actual bridge.
4. Add a native validation target or script that runs real native tests.
5. Make Hermes command parity deterministic or remove the static catalog.
6. Add stricter TS checks if they produce actionable failures.
7. Keep validation commands listed in `AGENTS.md` accurate.

## Files To Inspect

- `README.md`
- `AGENTS.md`
- `docs/hermes-layer.md`
- `docs/integrations.md`
- `docs/native-macos.md`
- `docs/intelligence-feature-spec.md`
- `docs/writing-system.md`
- `macos/Package.swift`
- `macos/Tests/`
- `src/test/jobmaxxing.test.ts`
- `src/lib/companies.ts`
- `scripts/install_hermes_layer.sh`
- `scripts/hermes_update.sh`

## Acceptance Criteria

- README matches the current native app surface.
- Hermes docs do not claim behavior that the native app cannot perform.
- Integration docs state what is stored locally.
- Native tests run from a documented command.
- Hermes parity tests are deterministic.
- Strict unused checks are either part of validation or intentionally excluded with rationale.
- `AGENTS.md` remains accurate.

## Tests And Verification

Run:

```bash
npm test
npm run lint
npm run build
npm run smoke
./script/build_and_run.sh --verify
```

Also run any native test command added by this thread.

## Risk Notes

- Do not document aspirational behavior as current behavior.
- Do not hide known gaps.
- Keep docs short and operational.
