# App Icons

The iOS source icons are 1024x1024 opaque square PNGs. iOS applies the
outer rounded mask at display time, so the source files intentionally do not
bake in rounded outer corners.

Geometry used for the centered mark:

- Canvas: 1024x1024.
- iOS mask preview radius: 228px, a rounded-rectangle approximation for QA.
- Mark box: 168x640, centered at 512,512.
- Mark radius: `round(168 * 228 / 1024) = 38px`.

That keeps the mark corner radius proportional to the icon mask radius without
turning the mark into a full pill.
