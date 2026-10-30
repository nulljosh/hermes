# Hermes loop handoff (2026-10-30, 10.4.0)

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

- 2026-10-30: 10.4.0. Hermes keeps the Apple password in its own Keychain item and passes it to asc on every web command. asc ran with its keychain bypassed, so it could not see its own saved password, which is why web sessions kept dying. Resolve All also signs itself back in once when the session expires, reading the 2FA code from Messages. Released as a notarized DMG on GitHub (v10.4.0). Not yet tested live.
- 2026-10-30: 10.3.0 (Add to New Submission on an in-app event), 10.2.0 (Liquid Glass on Resolve All, macOS 26 only, plain fallback below), 10.1.0 (app icon, name and version at the top of Settings, Mercury wallpapers). All notarized on GitHub. 21 of 21 unit tests pass.
- Issues #1 (custom font, system font only), #2 (Liquid Glass, closed by 10.2.0) and #3 (Product Hunt price, stays Free for now) are closed. The repo has no open issues or PRs.
- App Store Connect has 10 review submissions in UNRESOLVED_ISSUES across 8 apps: Patois iOS, Mailbag Mac, Oohaah Mac and iOS, Scrounger iOS, Cartons iOS, Sidewise iOS (retired), Horula Mac and iOS, Atlin iOS. None of the threads have been read, because the Apple web session expired. An earlier "0 rejections" reading was wrong.
- Blocked on Joshua: one sign-in inside Hermes (Resolve All, then Sign In) when he is back at his desk. The terminal asc-login timed out and was not retried, since Apple throttles.
- Known gap: the Dock icon would not open the app. Worked around by launching dist/Hermes.app directly. Root cause not confirmed.
- The parity matrix still has open rows: in-app event assets (todo) and the event archive (kept on the Mac, since App Store Connect has no archive).

## Next, in order

1. Joshua signs in inside Hermes (Resolve All, then Sign In). Nothing runs before that.
2. Read the 10 open threads, draft replies, and send only on Joshua's yes. Never send unchanged, and check the listing name before replying.
3. 10.5.0: TestFlight aliases, which are Mac-only today. Bring them to the iPhone companion if Joshua wants it.
4. In-app event assets, the last todo row in the events band.
5. Side-by-side Helm QA of every tab on a real app, when Joshua is at the Mac. Declaring 1:1 waits on that.
6. Review-time estimates wait for a decision date source. asc review history has the submit date only.

## Restart prompt

```
/loop Hermes: read docs/LOOP-HANDOFF.md and docs/roadmap.md. If Joshua has not yet signed in inside Hermes, stop and ask him for that one sign-in. Otherwise do the next item as the next minor version (10.5.0 next). Versioning is honest semver: features are minors, fixes are patches, a major only on Joshua's call. QA each change on a real app, notarize the DMG for the GitHub release, and never mutate a live app or send an Apple reply without Joshua's yes.
```
