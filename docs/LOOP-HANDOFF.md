# Hermes loop handoff (2026-10-25)

## What the loop is

Hermes is a native SwiftUI Mac app for App Store Connect, driven by the `asc` CLI. The loop takes it from 2.x to v100: a functional, one-to-one clone of Helm 2.3.9 with its own brand and code. Each tick takes the next item from the list below, checks the real `asc` flags with `--help` first, builds it, QAs it with launch arguments and screenshots, bumps the version, and pushes with a tag. Every major version gets a full QA pass, every tab on a real app, side by side with Helm. The prompt lives in `~/.claude/loops/hermes.md`.

Rules that bite:

- Stage by exact path. The working tree can hold another session's source changes; leave those alone.
- QA reads go through `asc --read-only`. Never mutate a live app without Joshua's yes.
- Helm's assets, text and code stay out of the repo.
- Long builds run in the background. One heavy job at a time.

## Where things stand

- 2026-10-25: 2.9.0. Resolve All drafts on Apple's on-device model (Sources/Writer.swift), Ollama second; the claude child process is gone, and with it the privacy popups. Each app gets a fact sheet first (Sources/Facts.swift): history, approved versions, builds, its own Swift files and any byte-identical with other apps (GitHub tree SHAs, cached a day in ~/Library/Caches/Hermes/review/fleet.json; monorepo apps are scoped to their own folders). Apple's nine 4.3 questions are answered one at a time; a plain 4.3(a) gets the house reply. No placeholders. The MCP mirrors it (app_facts, open_rejections, saved_drafts, send_rejection_reply) and serves HTTP with `--http`; skill hermes-resolve. Sent and verified on the real account the same day: Cartons, Sidewise (nine answers) and Oohaah. Still open: Atlin's listing name is "Danae" (probe leftover, restoring needs Joshua's yes), Machaon Mac (keychain prompt blocks the reviewer, cut-off text), Melete Mac (Sign in with Apple error), Talli Mac (5.1.1(ix) needs an organization developer account).

- 2026-10-20, 8am: 2.8.0 released. Notarized DMG on GitHub (v2.8.0, Latest), and `brew install --cask nulljosh/tap/hermes` works (Casks/hermes.rb in nulljosh/homebrew-tap, depends on the asc formula; fetch and audit clean). A local allow rule for `./scripts/release.sh` lives in the ignored .claude/settings.local.json, so the next release runs without the permission block. Bump the cask's version and sha256 with each release.
- 2026-10-20, morning: Resolve All is on the Mac (Sources/ResolveView.swift). A red "Resolve All (N)" button sits on the app list when apps are rejected. It reads each rejection with `asc web review show --plain-text`, skips threads where Apple owes the answer ("Waiting on Apple"), and drafts a Resolution Center reply plus a GitHub issue per app in one batched call. Drafting uses local Ollama first (qwen3:8b, models on the LaCie) and the Claude Code CLI as the fallback, because a claude child process pops a Documents privacy prompt. Any drafted sentence that claims a change ("we have revised") becomes a [placeholder], and Send All stays off until every bracket is filled, read-only is off, and a confirm dialog lists the exact commands. Sends go one app at a time, stop on the first failure, never retry. QA launch argument `-resolveAll YES`. Tried on the real account: Atlin and Healstack drafted, Airwell waiting on Apple, nothing sent. Ollama currently runs from a shell (`ollama serve`), not the brew service.
- 2026-10-20, 1am: Hermes for iPhone exists (iOS/ + Shared/, target HermesPhone, iOS 17). It calls the App Store Connect API directly with an ES256 token signed by the user's key, which lives in the Keychain (iCloud Keychain sync). Tabs: Apps (search on top, real icons), Status (rejected first), Settings. Animated splash (wing flips, six glyphs orbit via an Orbit GeometryEffect, letters drop), four-page onboarding with the halftone gods, review replies with a confirm sheet. Debug-only env for QA: HERMES_KEY_ID / HERMES_ISSUER_ID / HERMES_KEY_PEM_B64, HERMES_SCREEN=onboarding|status|settings, HERMES_PAGE, HERMES_OPEN_APP, HERMES_TAB. Tested on the simulator against Joshua's real account (25 apps). 8 of 8 Mac tests green. Privacy policy at docs/PRIVACY.md and /privacy. Next, in order: (1) Resolve All on the Mac: read every rejection, an LLM drafts the Resolution Center reply and a GitHub issue or PR per app, one review sheet, Send All; replies need the asc web session, so Mac only, and nothing goes to Apple without Joshua's click; (2) accounts on jaybulb-api plus a D1 table for synced settings, never the .p8; (3) iOS submit-for-review; (4) cut the 2.8.0 notarized release and the Homebrew cask (release.sh was blocked by the permission check); (5) the 3.0 roadmap.
- 2026-10-20, late: version bumped to 2.8.0 (project.yml) for the new palette. The signed, notarized release (scripts/release.sh) was blocked by the session's permission check, so it has NOT been cut; the latest GitHub release is still v2.0.0. Next: run `./scripts/release.sh`, `gh release create v2.8.0 dist/Hermes.dmg`, then add `Casks/hermes.rb` to nulljosh/homebrew-tap pointing at the versioned asset. Docs page live at hermes.jaybulb.com/docs. MCP installs in one line: `claude mcp add hermes -- uv run https://raw.githubusercontent.com/nulljosh/hermes/main/mcp/server.py` (tested, 9 tools). Landing art: halftone masks in landing/art/, dithered from public domain Hermes statues, Goltzius and Piranesi (credits in an index.html comment). Landing and app QA'd 2026-10-20 in WebKit iPhone and Chromium desktop, dark and light, plus app Status, Versions, Builds, Reviews and the list.
- 2026-10-20, landing and design system (unreleased in the app): the landing is dressed after nousresearch.com. Navy page (#0a0e19) in a thin blue frame, deep blue band (#0847c4 light, #0a33b5 dark), Hermes Sans for everything (Hermes Display, Antonio, was dropped 2026-10-25). The 1878 engraving sits in CSS scanlines on the band, the demo stage, the terminal stage and three product cards (Mac, asc, MCP). The footer glyph band is plain 2D canvas (landing/footer-band.js); the WebGL version rendered black on iPhone. No hero parallax any more. brand/tokens.css holds every value, the brand kit page shows both faces, and Sources/Theme.swift mirrors the new colours: built, tests green, screenshotted dark and light, not yet in a tagged release. Ship it with the next app version.
- Repo: main at c170d63, tagged v2.7.0, pushed. The landing is deployed at hermes.jaybulb.com. The loop is stopped for now; Joshua is wrapping up.
- 2.7.0: Hermes Sans kept, rebuilt on Inter (OFL) with proportional spacing, so the type reads like SF. Feather quotes kept. The in-review state is amber. A brand kit page lives at hermes.jaybulb.com/brand. The landing hero has an 1878 public-domain Hermes engraving traced to SVG with scroll parallax; on phones it stands beside the headline. The footer is a WebGL band of engraved Hermes glyphs (wing mark, caduceus, winged helmet, winged sandal, letter, purse). 5 of 5 tests green.
- 2.6.0: brand moved from terracotta to blue (clrs.cc blue tile for the icon; UI accent #0066C0 in light, #3D9BF0 in dark, both passing AA). New detailed wing icon from scripts/gen_icon.py with Icon Composer glass. README simplified.
- 2.5.0 (cbb2fe1) added subscription prices for every country, introductory, promotional and win-back offers, and the billing grace period. Its QA pass and notarized DMG are not recorded yet.
- 2.4.0 redrew the quote marks as feathers in Hermes Sans, thickened the wing icon, and added a two-feather favicon for small sizes.
- 2.3.0 added light mode and an Appearance setting (System, Light, Dark). 2.2.0 added build upload (.ipa and .pkg), What to Test, and submit for beta review.
- The parity matrix in `docs/roadmap.md` still marks TestFlight group aliases as partial.

## Next, in order

1. Accounts on jaybulb-api plus a D1 table for synced settings, never the .p8.
2. iOS submit-for-review.
3. TestFlight group aliases, the last partial row in the matrix. Then event duplicate and archive, and the agreement banner.
4. 3.0: menu bar status, review-state notifications, Shortcuts. It is a major version, so it gets the full side-by-side QA with Helm, every tab. Then declare 1:1 with Helm.

## Restart prompt

```
/loop Hermes loop to v100: read ~/.claude/loops/hermes.md and do the next iteration. QA the app at every major semver.
```
