# Native Workflow And UI Simplification

## Goal

Make the native app faster to understand and easier to operate. The app should show the useful hiring workflow first and hide agent/admin chrome unless needed.

## Actual Problem

The native app has too many panels, repeated cards, and hidden state changes:

- Dashboard rows set hidden selection without clear navigation.
- Applications keyword chips split words in narrow layouts.
- Companies and Contacts show large agent/trace panels that crowd the work.
- Companies duplicates contact workflow controls.
- Some buttons mutate state while looking like navigation.
- Document modes appear selectable but do not change meaningful behavior.
- Settings mixes provider status, connector setup, runtime scripts, and policy in dense panels.

The screenshot adds one concrete UI bug:

- Chat user messages can visually overlap the assistant transcript.

## Proposed Fix

Be critical of this proposal before implementing it. Remove UI before adding UI.

1. Convert hidden selection actions into real navigation or remove the action.
2. Use dense lists/tables for repeated operational data.
3. Move agent trace details behind disclosure.
4. Keep Contacts as the owner of contact/WhatsApp actions.
5. Keep Companies focused on company facts, role context, and people map links.
6. Fix chip layout with wrapping grids or truncation that never splits words awkwardly.
7. Remove inert document modes or wire each mode to distinct output.
8. Make Chat rows use fixed readable widths and stable vertical layout.
9. Reduce Settings to status, action, and risk.

## Files To Inspect

- `macos/Sources/Jobmaxxing/Views/DashboardView.swift`
- `macos/Sources/Jobmaxxing/Views/ApplicationsView.swift`
- `macos/Sources/Jobmaxxing/Views/CompaniesView.swift`
- `macos/Sources/Jobmaxxing/Views/ContactsView.swift`
- `macos/Sources/Jobmaxxing/Views/Components.swift`
- `macos/Sources/Jobmaxxing/Views/HermesChatView.swift`
- `macos/Sources/Jobmaxxing/Views/HermesChatRows.swift`
- `macos/Sources/Jobmaxxing/Views/SettingsView.swift`
- `macos/Sources/Jobmaxxing/Views/ContentView.swift`
- `macos/Sources/Jobmaxxing/Views/SidebarView.swift`

## Acceptance Criteria

- Every visible button either navigates, mutates with clear copy, or opens an explicit external handoff.
- No primary workflow depends on hidden selection state.
- Long chat messages never overlap other content.
- Keyword chips do not split words awkwardly.
- Contacts and Companies do not duplicate the same contact actions.
- Agent trace chrome is not dominant on company/contact pages.
- Settings shows truthful status and fewer controls per screen.
- Narrow-window behavior is inspected in the packaged app.

## Tests And Verification

Run:

```bash
npm test
npm run lint
npm run build
./script/build_and_run.sh --verify
```

Manual native checks:

- Dashboard row actions.
- Applications detail and keyword layout.
- Companies list and detail.
- Contacts list and detail.
- Chat long message layout.
- Writing audit.
- Interviews page.
- Browser plan.
- Settings status pages.
- Narrow and wide window sizes.

## Risk Notes

- Do not remove user-critical context.
- Do not hide safety states.
- Do not create new pages when a disclosure or inline action solves the problem.
