---
name: visual-qa
description: Capture and report visual QA screenshots for One Thing UI changes before push or release. Use after building any frontend-visible feature, layout change, styling change, browser/extension UI change, or when asked to verify the app visually across sizes and states.
---

# Visual QA

For One Thing UI work, always verify the real app visually before push/release. Prefer the web version at `index.html`; use `extension/newtab.html` too when extension-specific behavior could differ.

## Default Screenshot Matrix

Capture a small, useful set:

- Desktop empty light: `1280x860`, no seeded plan data.
- Desktop filled light: `1280x860`, realistic localStorage for the changed feature.
- Relevant behavior state: same viewport, after the key interaction or date/state change.
- Desktop filled dark: same seeded state with `onething-theme=dark` when styles changed.
- Mobile filled light: `390x844`, same seeded state.

Skip a shot only when it is clearly irrelevant, and say why. Add extra shots for states touched by the feature, such as sidebar open, sync connected/error, completed items, long text, date navigation, or extension page.

## How

Use Playwright or the in-app browser. Seed localStorage before page load so screenshots are deterministic. Save screenshots under `/private/tmp/<project>-qa-<feature>/`.

For this app, the usual URL is:

```text
file:///Users/sam/Developer/one-thing/index.html
```

When using Playwright, capture real PNG files and then show them in the final response with Markdown image links using absolute paths.

## Report

In the final response:

- Include each screenshot with a short label.
- Mention the states and viewport sizes covered.
- Call out visual issues found, even if you fixed them.
- If screenshots could not be captured, explain the blocker and what was verified instead.

Keep it lightweight. The goal is a habit that catches obvious layout regressions, not a full design review ceremony.
