# Hermes brand kit and design system

A wing from Hermes' sandals: the messenger who carries your app to the store.

## The mark
One bold flat white glyph on an accent gradient tile. No text, no outline, no emblem.

- `../Hermes.icon` is the source of truth (Icon Composer). Light and dark fills are set in it.
- `../icon.svg` is the flat copy for READMEs (shown at 80 px). `icon-1024.png` is the App Store icon, no alpha.
- `mark.svg` is the glyph alone in `currentColor` for your own background.
- Clear space equal to the width of the glyph's thickest stroke.
- At 32 px and below use `favicon.svg`: two thicker feathers instead of three, so it still reads at 16 px.

## Colour
Warm paper in light, warm graphite in dark. One accent, flat surfaces, no gradients except the icon tile, no shadows.

| Role | Light | Dark |
|---|---|---|
| Accent (actions, links, icon) | `#0074D9` (clrs.cc blue) | `#3D9BF0` |
| Background | `#faf8f4` | `#171614` |
| Surface (cards, sidebar, hover) | `#f1ede6` | `#211f1c` |
| Line | `#e3ddd3` | `#33302b` |
| Text | `#1f1d1a` | `#f3efe8` |
| Secondary text | `#6b655c` | `#9a948a` |

State dots, the same everywhere a version shows: on sale `#4caf6e`, in review or processing `#5b9bd5`, rejected `#d9534f`, preparing `#6f6a62` (dark values; light values are in `tokens.css`).

## Type
Hermes Sans, the house face for this app: Instrument Sans under the SIL Open Font License, renamed and pinned by `scripts/gen_font.py`, with the curly quotes and apostrophe redrawn as feathers from the wing. Four weights, 400 to 700. The fallback is the system stack. Scale: display 64/64 bold, title 34/40 bold, headline 20/28 semibold, body 17/24, footnote 13/16. The app uses 17 semibold for titles, 14 semibold for rows and 11 medium for version lines.

## Space and shape
- Space on the 8 point grid: 4, 8, 12, 16, 24, 32, 48. Side margin 20. Reading column 680.
- Radii: cards 28, grouped lists 20, controls fully round, icon 22 percent.
- Controls are 48 points tall capsules, one height in a row. Focus is a 4 point ring at 30 percent accent.
- Motion is 0.2 s ease and honours reduced motion.

`tokens.css` is the single source for the landing; `Sources/Theme.swift` mirrors it for the app. Rows hover to the surface colour with an 8 point radius.
