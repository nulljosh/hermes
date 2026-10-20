# Hermes loop handoff (2026-10-19, night)

## What the loop is

Hermes is a native SwiftUI Mac app for App Store Connect, driven by the `asc` CLI. The loop takes it from 2.x to v100: a functional, one-to-one clone of Helm 2.3.9 with its own brand and code. Each tick takes the next item from the list below, checks the real `asc` flags with `--help` first, builds it, QAs it with launch arguments and screenshots, bumps the version, and pushes with a tag. Every major version gets a full QA pass, every tab on a real app, side by side with Helm. The prompt lives in `~/.claude/loops/hermes.md`.

Rules that bite:

- Stage by exact path. The working tree can hold another session's source changes; leave those alone.
- QA reads go through `asc --read-only`. Never mutate a live app without Joshua's yes.
- Helm's assets, text and code stay out of the repo.
- Long builds run in the background. One heavy job at a time.

## Where things stand

- Repo: main at c170d63, tagged v2.7.0, pushed. The landing is deployed at hermes.jaybulb.com. The loop is stopped for now; Joshua is wrapping up.
- 2.7.0: Hermes Sans kept, rebuilt on Inter (OFL) with proportional spacing, so the type reads like SF. Feather quotes kept. The in-review state is amber. A brand kit page lives at hermes.jaybulb.com/brand. The landing hero has an 1878 public-domain Hermes engraving traced to SVG with scroll parallax; on phones it stands beside the headline. The footer is a WebGL band of engraved Hermes glyphs (wing mark, caduceus, winged helmet, winged sandal, letter, purse). 5 of 5 tests green.
- 2.6.0: brand moved from terracotta to blue (clrs.cc blue tile for the icon; UI accent #0066C0 in light, #3D9BF0 in dark, both passing AA). New detailed wing icon from scripts/gen_icon.py with Icon Composer glass. README simplified.
- 2.5.0 (cbb2fe1) added subscription prices for every country, introductory, promotional and win-back offers, and the billing grace period. Its QA pass and notarized DMG are not recorded yet.
- 2.4.0 redrew the quote marks as feathers in Hermes Sans, thickened the wing icon, and added a two-feather favicon for small sizes.
- 2.3.0 added light mode and an Appearance setting (System, Light, Dark). 2.2.0 added build upload (.ipa and .pkg), What to Test, and submit for beta review.
- The parity matrix in `docs/roadmap.md` still marks TestFlight group aliases as partial.

## Next, in order

1. TestFlight group aliases, the last partial row in the matrix.
2. Event duplicate and archive.
3. Agreement banner.
4. 3.0: menu bar status, review-state notifications, Shortcuts.
5. 3.0 is a major version, so it gets the full side-by-side QA with Helm, every tab. Then declare 1:1 with Helm.

## Restart prompt

```
/loop Hermes loop to v100: read ~/.claude/loops/hermes.md and do the next iteration. QA the app at every major semver.
```
