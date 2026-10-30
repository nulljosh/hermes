# Hermes loop handoff (2026-10-30, 10.3.0)

## What the loop is

Hermes is a native SwiftUI Mac app for App Store Connect, driven by the `asc` CLI. The loop works through the open rows of the parity matrix in docs/roadmap.md, one item at a time, toward a one-to-one clone of Helm 2.3.9 with its own brand and code. Each tick takes the next item, checks the real `asc` flags with `--help` first, builds it, QAs it with launch arguments and screenshots, bumps the version, and pushes with a tag.

Versioning is honest semver. A feature is a minor bump, a fix is a patch, and a major only on Joshua's call. The loop does not aim at any version number.

Rules that bite:

- Stage by exact path. The working tree can hold other changes, including an untracked `.build/`. Leave those alone.
- QA reads go through `asc --read-only`. Never mutate a live app without Joshua's yes.
- Helm's assets, text and code stay out of the repo.
- Long builds run in the background. One heavy job at a time.
- Never open a fresh build headless. Test through the MCP or scripts/try-writer.sh.

## Where things stand

- 2026-10-30: 10.3.0, Add to New Submission on an in-app event (asc review items-add appEvents). Before it, 10.2.0 added Liquid Glass on Resolve All (macOS 26 only, plain fallback below), and 10.1.0 added the app icon, name and version at the top of Settings and Mercury wallpapers. Each is notarized on GitHub. Tests: 21 of 21 pass. Not run yet: a live Resolve All pass on real threads.
- Issues #1 (custom font, closed: system font only), #2 (Liquid Glass, closed by 10.2.0) and #3 (Product Hunt price, closed: stays Free for now) are all closed. Nothing is open on the repo.
- Known gap: the Dock icon launch problem was worked around by launching dist/Hermes.app directly. The root cause is not confirmed.
- The parity matrix still has open rows: in-app event assets (todo) and in-app event archive (kept on the Mac because App Store Connect has no archive).
- The App Store Connect fleet read on 2026-10-30 showed 28 apps and 0 rejected versions.

## Next, in order

1. Next minor is 10.4.0. Take the first open row of the parity matrix.
2. TestFlight aliases are Mac-only today. Bring them to the iPhone companion if Joshua wants it.
3. In-app event assets, the last todo row in the events band.
4. Side-by-side Helm QA of every tab on a real app, when Joshua is at the Mac. Declaring 1:1 waits on that.
5. Review-time estimates wait for a decision date source. asc review history has the submit date only.

## Restart prompt

```
/loop Hermes: read docs/LOOP-HANDOFF.md and docs/roadmap.md, then do the next item as the next minor version (10.4.0 first). Versioning is honest semver: features are minors, fixes are patches, a major only on Joshua's call. QA each change on a real app, notarize the DMG for the GitHub release, and never mutate a live app without Joshua's yes.
```
