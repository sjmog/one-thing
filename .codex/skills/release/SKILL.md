---
name: release
description: Push and release One Thing end-to-end. Use when the user types $release or asks to push, publish, ship, or release the app; runs visual QA first, includes screenshots in the GitHub/release summary, bumps versions, packages the extension, pushes main and the version tag, and publishes the Electron GitHub release.
---

# Release

`$release` means: finish the feature, visually QA it, push it, and publish the release.

## Guardrails

- Inspect `git status --short --branch` first.
- Do not stage unrelated local changes. If unrelated files are dirty, leave them alone and mention them.
- Prefer the smallest patch version bump across `extension/manifest.json`, `electron/package.json`, and `electron/package-lock.json`.
- If the change is UI-visible, run `.codex/skills/visual-qa/SKILL.md` before commit.
- GitHub push, PR, or release summaries must include the QA screenshots or links to the screenshot files.
- Do not claim Chrome Web Store publication unless it was actually uploaded. A prepared/uploaded GitHub release asset is not the same thing.

## Flow

1. Review the final diff and choose the intended release files.
2. For UI-visible changes, capture visual QA screenshots:
   - Load the real app, usually `file:///Users/sam/Developer/one-thing/index.html`.
   - Capture the default visual QA matrix from `.codex/skills/visual-qa/SKILL.md`.
   - Save screenshots under `/private/tmp/one-thing-qa-<feature>/`.
3. Bump versions when releasing app/extension changes:
   - `extension/manifest.json`
   - `electron/package.json`
   - `electron/package-lock.json`
4. Rebuild the Chrome extension zip when extension files changed:
   - Zip the contents of `extension/`, not the folder itself.
   - Keep/update `one-thing-chrome-store.zip`.
5. Smoke test the real app and extension page with Playwright when practical.
6. Stage only intended files and commit with a concise message.
7. Create a matching tag, e.g. `v1.5.12`.
8. Push `main` and the tag.
9. Run `cd electron && npm run release`.
10. Upload the extension zip to the GitHub release as `one-thing-extension.zip` if the extension changed.
11. Final response must include:
    - Commit hash and version tag.
    - GitHub release URL.
    - What was released.
    - Visual QA screenshots.
    - Any manual follow-up, especially Chrome Web Store upload.
    - Any unrelated dirty files left untouched.

## Useful Commands

```bash
git status --short --branch
git diff --stat
zip -r ../one-thing-chrome-store.zip FunnelSans.woff2 favicon-16-dark.png favicon-16.png favicon-32-dark.png favicon-32.png favicon-dark.ico favicon.ico icon128.png icon16.png icon48.png manifest.json newtab.html
git push origin main vX.Y.Z
cd electron && npm run release
gh release upload vX.Y.Z /private/tmp/one-thing-extension.zip --clobber
```

Keep the ceremony boring. If a step cannot be completed, stop and say exactly what remains.
