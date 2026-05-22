---
name: release-ios
description: Release the native One Thing iOS SwiftUI app. Use when the user types $release-ios, asks to release/install/archive the iOS app, or wants a personal-device, TestFlight, or App Store iOS release; verifies native Swift only, signing, simulator QA, visual-qa screenshots, versioning, and safe git handling without releasing Electron or Chrome unless explicitly changed.
---

# Release iOS

`$release-ios` means: finish and verify the native iOS app in `ios/`, prepare a signed iOS release path, commit/tag the intended iOS changes, and report exactly how to install or distribute it.

## Guardrails

- Inspect `git status --short --branch` first. Stage only intended files; leave unrelated dirty files alone and mention them.
- Keep the app native Swift/SwiftUI. Do not add `WKWebView`, packaged HTML UI, remote web screens, or a JavaScript bridge.
- Default channel is personal-device install from Xcode unless the user explicitly asks for TestFlight or App Store.
- Do not run the general `$release` Electron/Chrome flow unless Electron, extension, web, or backend files changed and the user wants those channels released too.
- For App Store or TestFlight, verify current Apple submission/toolchain requirements from official Apple docs before upload; SDK rules change over time.
- Prefer `gt` for branch/PR flow. Raw `git` is fine for tags, status, and simple local operations.

## Current Repo Defaults

- Project: `ios/OneThing.xcodeproj`
- Scheme: `OneThing`
- Bundle id: `com.sjmog.onething`
- Team: `ME2EKHSSAN`
- Signing: automatic
- Version fields live in `ios/OneThing.xcodeproj/project.pbxproj` as `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`.

Do not trust these from memory. Confirm them before release:

```bash
rg -n "PRODUCT_BUNDLE_IDENTIFIER|DEVELOPMENT_TEAM|CODE_SIGN_STYLE|MARKETING_VERSION|CURRENT_PROJECT_VERSION" ios/OneThing.xcodeproj/project.pbxproj
```

## Release Channel Decision

Use the smallest channel that matches the user request:

- **Personal device**: simulator QA, generic iOS signed build, commit/tag, then give Xcode install steps. No App Store archive.
- **TestFlight/App Store**: all personal-device checks, version bump, archive, export/upload through Xcode or `xcodebuild`/`xcrun altool` only after verifying current Apple requirements.
- **Code-only checkpoint**: tests, simulator QA, commit, optional tag, no device/archive claim.

If the user just says "release this" while working on iOS, use personal-device release.

## Versioning

For an iOS release, bump only iOS version fields unless other channels changed:

- Increment `CURRENT_PROJECT_VERSION` by 1.
- Patch-bump `MARKETING_VERSION` only for a user-facing release. Keep it aligned across Debug/Release target settings.
- Do not bump `extension/manifest.json`, `electron/package.json`, or `electron/package-lock.json` for iOS-only releases.

## Required Verification

Run these before committing:

```bash
xcodebuild -project ios/OneThing.xcodeproj -scheme OneThing -destination 'platform=iOS Simulator,name=iPhone 16' test
xcodebuild -project ios/OneThing.xcodeproj -scheme OneThing -destination 'generic/platform=iOS' -allowProvisioningUpdates build
rg -n "WKWebView|WebKit|loadHTMLString|loadRequest|UIViewRepresentable" ios
security find-identity -v -p codesigning
git diff --check
```

Signing notes:

- `Developer ID Application` signs the macOS Electron app; it is not enough for iOS.
- Personal-device install needs a usable `Apple Development` identity and Xcode-managed provisioning for `com.sjmog.onething`.
- App Store/TestFlight needs the appropriate distribution signing and App Store Connect setup. If signing does not match the requested channel, stop on signing, not app code.

## Visual QA

For every UI-visible iOS release, read and follow `.codex/skills/visual-qa/SKILL.md`.

Native simulator minimum:

- iPhone filled light.
- iPhone filled dark when colors/completion/strike states changed.
- iPad when split view/sidebar layout changed.
- A focused screenshot for the changed interaction, such as completed multiline rows, date navigation, sync panel, or keyboard state.
- At least one alignment overlay or crop with guide colors, saved under `/private/tmp/one-thing-qa-ios-<feature>/`.

Use `xcrun simctl` for deterministic native QA:

```bash
xcrun simctl boot <device-id>
xcrun simctl install <device-id> <DerivedData>/Build/Products/Debug-iphonesimulator/OneThing.app
xcrun simctl spawn <device-id> defaults write com.sjmog.onething <key> <value>
xcrun simctl launch <device-id> com.sjmog.onething
xcrun simctl io <device-id> screenshot /private/tmp/one-thing-qa-ios-<feature>/<state>.png
```

When HTML parity might have drifted, run `$syncios` first or explicitly compare against `index.html` before releasing.

## Personal Device Install Steps

After tests and the generic build pass:

1. Open `ios/OneThing.xcodeproj` in Xcode.
2. Select the `OneThing` scheme.
3. Select the connected iPhone/iPad as the run destination.
4. In Signing & Capabilities, confirm automatic signing uses team `ME2EKHSSAN`.
5. Press Run. Trust the developer profile on the device if iOS asks.

Do not claim the app is on the device unless this install was actually performed or the user performs it.

## Commit, Tag, Push

Before staging, review the final diff:

```bash
git diff --stat
git diff -- ios
```

Stage only intended files. For an iOS-only release this is usually:

```bash
git add ios/OneThing.xcodeproj/project.pbxproj ios/OneThing ios/OneThingTests
```

Use a concise commit message such as:

```text
Release iOS 1.5.26
```

Create an iOS-specific tag to avoid implying Electron/Chrome were published:

```bash
git tag ios-v1.5.26
git push origin main ios-v1.5.26
```

If using a PR instead of pushing main directly, include simulator screenshots and test/build results in the PR body.

## Final Report

Include:

- Commit hash and iOS tag, if created.
- iOS version/build number.
- Release channel used: personal device, TestFlight/App Store, or code-only checkpoint.
- Tests/builds/signing checks run and result.
- Visual QA screenshot paths with a short state label.
- Whether WebView grep was clean.
- Install/upload steps completed and any manual follow-up.
- Unrelated dirty files left untouched.

If any step fails, stop and state the exact blocker plus the next command or Xcode action needed.
