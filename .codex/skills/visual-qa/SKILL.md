---
name: visual-qa
description: Capture and report visual QA screenshots for One Thing UI changes before push or release. Use after building any frontend-visible feature, layout change, pixel-alignment change, styling change, browser/extension UI change, or when asked to verify the app visually across sizes and states.
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

## Required Alignment Overlays

Always include at least one alignment overlay pass for One Thing visual QA. Even when the visible change is not obviously about alignment, capture one representative state with guides so regressions in anchoring, spacing, or content alignment are easy to spot.

When the work is about alignment, spacing, centering, or “pixel perfect” polish, expand this into a tighter overlay pass across every affected state instead of relying on eyeballing alone.

Use Playwright to measure real DOM boxes with `getBoundingClientRect()`, then draw fixed-position guide rectangles before screenshotting:

- Green vertical/horizontal line: the intended target edge or centerline.
- Blue rectangles: content or reference elements that must align to the target.
- Red rectangles: the changed control, picker, chip, pill, or popup.
- Purple rectangles: Electron-only drag regions or invisible interaction regions.

For each alignment-sensitive state:

- Capture at least one close crop with overlays.
- Include the normal screenshot too when useful for context.
- Check the default state and any state that changes the coordinate system, such as sidebar open, mobile, extension page, dark mode, hover, picker open, or Electron-only mode.
- Report measured values and deltas in pixels. Treat anything over `0.25px` as worth investigating unless there is a clear rendering reason.
- Re-run the overlay pass after simplification/refactoring, not just after the first implementation.

Prefer DOM overlays to image post-processing: append temporary `.qa-guide` elements with `position: fixed`, `pointer-events: none`, and a high `z-index`. Do not use CSS `border` for guide boxes because it can change layout; use layout-neutral `box-shadow: inset 0 0 0 2px <color>` for rectangles and 1px fixed-position background fills for grid lines. Remove old `.qa-guide` elements before drawing a new set.

## Vertical Rhythm Grids

When the work is about vertical spacing or rhythm, add a rhythm-grid overlay on top of the rectangle pass.

Anchor the grid to a real stable visual feature, not an arbitrary page top. For this app, prefer the hamburger because it is aligned with the macOS window controls and should not move. Useful anchors include the hamburger SVG centerline, its individual stroke centers, or its visible ink bounds.

Measure rendered content, not just container boxes:

- Use `Range#getClientRects()` on text nodes/elements to capture browser-rendered line boxes.
- Use canvas `measureText()` with the element's computed font to estimate actual glyph ink via `actualBoundingBoxAscent` and `actualBoundingBoxDescent`.
- Keep element `getBoundingClientRect()` too, but treat it as the layout box, not the final visual truth.

Compare a few candidate rhythms before changing CSS:

- Boring base grids: `4px`, `6px`, `8px`.
- Golden-ratio ladder: `5px`, `8px`, `13px`, `21px`, `34px` (`5 * phi^n`, rounded).
- Hybrid: use a small base grid (`4px`) for micro-alignment and golden-ratio intervals (`13/21/34px`) for section spacing.

Score each candidate by measuring distance from rendered text line tops, centers, bottoms, and estimated ink centers to the nearest grid line. Favor the rhythm that makes related content land consistently without moving important anchors. Report the chosen anchor, candidate intervals, and pixel deltas.

Draw the rhythm grid as layout-neutral fixed overlays. Use faint horizontal lines for the base grid, stronger lines for major intervals, and keep guide rectangles on top with `box-shadow`, not `border`.

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
- For alignment overlays, explain the color legend and include the measured pixel values/deltas.
- For vertical rhythm grids, mention the anchor, rhythm candidates considered, and which rendered text measurements were used (`Range` boxes, canvas ink metrics, or both).
- Call out visual issues found, even if you fixed them.
- If screenshots could not be captured, explain the blocker and what was verified instead.

Keep it lightweight. The goal is a habit that catches obvious layout regressions, not a full design review ceremony.
