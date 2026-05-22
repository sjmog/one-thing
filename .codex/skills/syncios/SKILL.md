---
name: syncios
description: Keep the native iOS SwiftUI app in full parity with the frequently updated HTML One Thing app. Use when the user types $syncios, asks to sync iOS with index.html, or wants iOS feature, layout, sync, or visual parity; requires native Swift, no WebView, simulator QA, tests, and visual-qa screenshots.
---

# Sync iOS With HTML

`index.html` is the source of truth because it changes most often. The iOS app in `ios/` is a native SwiftUI mirror of that app: same features, data behavior, layout, copy, and visual feel, but not a WebView.

## Non-Negotiables

- Native Swift/SwiftUI only. Do not add `WKWebView`, packaged HTML UI, remote web screens, or a JavaScript bridge for the app interface.
- Keep the web app, Chrome extension, Electron app, and backend unchanged unless parity tests prove a real incompatibility.
- Prefer small, direct Swift changes in the existing files over new abstractions.
- Keep one short `update_plan` item current while doing real work.
- For UI-visible work, read and follow `.codex/skills/visual-qa/SKILL.md` before final reporting.

## Source-Of-Truth Pass

Before editing Swift, inspect `index.html` for the exact behavior being mirrored:

- Render functions, event handlers, localStorage keys, and sync code.
- CSS tokens: font, colors, spacing, border radii, shadows, widths, and breakpoints.
- Copy, empty states, sort order, completed item behavior, date keys, and Monday week keys.
- Sync record shapes, record types, HLC conflict rules, tombstones, outbox behavior, and setting keys.

Useful starting search:

```bash
rg -n "localStorage|/v2/push|/v2/pull|niceToDo|week|theme|hide-completed|sidebar|HLC|tombstone" index.html
```

Do not rely on memory when HTML may have changed recently. Re-read the relevant HTML/CSS/JS first.

## Implementation Map

Use the current iOS project shape unless the code has moved:

- UI and layout: `ios/OneThing/ContentView.swift`
- State and business logic: `ios/OneThing/OneThingStore.swift`
- Models: `ios/OneThing/Models.swift`
- Persistence: `ios/OneThing/LocalPersistence.swift`
- Sync: `ios/OneThing/SyncEngine.swift`
- Tests: `ios/OneThingTests/`

Keep model and persistence names boring and close to the HTML concepts: `DailyPlan`, `NiceItem`, `WeekGoal`, `TodoItem`, `HLC`, and `SyncOp`.

## Sync Rules

- Mirror the existing `/v2/push` and `/v2/pull` protocol exactly.
- Preserve record types: `todo`, `plan`, `week`, and `setting`.
- Preserve HLC last-write-wins behavior, tombstones, sync cursor updates, outbox clearing after successful push, debounced push, and foreground pull.
- Store the sync passphrase in Keychain on iOS, even if HTML stores it in localStorage.
- Keep local data as Codable JSON and decode old HTML-compatible shapes where needed, especially old string-format `niceToDo` data.

## Visual Parity Workflow

1. Seed deterministic HTML state before page load and capture reference screenshots under `/private/tmp/one-thing-qa-ios-<feature>/`.
2. Seed the same state in the simulator and capture native screenshots for the same app states.
3. Cover iPhone for daily-plan-first behavior. Cover iPad when split-view/backlog layout changes.
4. Include light mode, dark mode, backlog/sidebar, completed items, long text, date/week navigation, and sync status when touched.
5. Downscale simulator screenshots to logical size before comparing against browser screenshots. Ignore hardware chrome such as Dynamic Island and home indicator; measure the app surface and content.
6. Use the `visual-qa` alignment overlay rules for every UI-visible change. For spacing or layout changes, also run vertical rhythm testing.

Overlay conventions:

- Green: stable anchor or target edge/centerline.
- Blue: content boxes that should align.
- Red: changed controls, toggles, chips, pickers, or sheets.
- Purple: content frame or native/web comparison frame.
- Orange/faint horizontal lines: rhythm grid.

For vertical rhythm, prefer the hamburger centerline as the stable anchor. Compare practical candidates such as `4px`, `5px`, `6px`, `8px`, `13px`, `21px`, and `34px`. On web, use DOM boxes plus text `Range`/canvas ink metrics. On native, use screenshot pixel boxes or clearly reported SwiftUI geometry. Investigate web deltas over `0.25px` and native/web content deltas over about `1px` after logical scaling unless there is a clear font or hardware reason.

## Verification

Run the narrowest useful tests first, then simulator QA:

```bash
xcodebuild -project ios/OneThing.xcodeproj -scheme OneThing -destination 'platform=iOS Simulator,name=iPhone 16' test
xcodebuild -project ios/OneThing.xcodeproj -scheme OneThing -destination 'generic/platform=iOS' -allowProvisioningUpdates build
rg -n "WKWebView|WebKit|loadHTMLString|loadRequest|UIViewRepresentable" ios
```

Use `xcrun simctl` to install, launch, seed defaults, and capture screenshots. If Xcode, simulator, signing, or keychain commands report sandbox-only failures, rerun with the needed escalation instead of treating the failure as app behavior.

Manual QA checklist:

- Create, edit, delete, and complete the daily goal.
- Create, edit, delete, and complete week goals, nice-to-dos, and backlog items.
- Verify iPhone backlog sheet, native date picker, and swipe-to-complete.
- Verify iPad split view.
- Verify dark mode, offline edits, reconnect sync, and manual sync.
- Cross-check with HTML/Electron using the same passphrase when sync behavior changed.

## Final Report

Include:

- The HTML behavior or CSS tokens mirrored.
- The iOS files changed.
- Tests/builds run and their result.
- Simulator states covered.
- Visual QA screenshot paths and measured alignment/rhythm deltas.
- Any remaining parity gap, with the reason it was left.

Do not finish until the native app builds, simulator QA passes, WebView grep is clean, and visual QA artifacts exist for UI-visible changes.
