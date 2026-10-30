# Hermes roadmap

Goal: a native Mac app for App Store Connect that matches Helm 2.3.9 feature for feature, with its own brand and code. Hermes drives the `asc` CLI, so auth and API coverage come from there.

Reference: `/Applications/Helm.app` (bundle id com.modumhq.Helm). Re-check the matrix every version. The truth for Helm's surface is its `helm-asc` command map in `Contents/Resources/AgentSkill_AgentSkill.bundle`.

## Parity matrix (v2.7.0)

| Area | Helm | Hermes | Status |
|---|---|---|---|
| App list, icons, search, refresh | yes | yes | done |
| Per-platform version and state dot | yes | yes | done |
| Two-pane welcome window | yes | yes | done |
| Release status and next action | yes | yes | done (Hermes adds blockers) |
| Version list | yes | yes | done |
| Create version, edit version, ship, reject | yes | create, edit, submit, release, delete, cancel submission | done |
| Review info (notes, demo account, attachments) | yes | contact, notes, demo account, attachments | done |
| Localizations: list, edit, bulk download and upload | yes | yes, plus App Info name and subtitle, character limits | done |
| Screenshots: view, upload, delete, download | yes | yes | done |
| App previews: view, upload, delete, frame time | yes | view, upload, delete, poster frame | done |
| Builds list | yes | yes | done |
| Build upload, expire, attach to version, submit for beta review | yes | upload .ipa/.pkg, expire, attach, add to group, What to Test, beta review | done |
| TestFlight groups | yes | yes | done |
| TestFlight group create, edit, testers, add builds, aliases | yes | create, edit, delete, testers, invite, add builds, copy public link | done (3.1: aliases are Hermes nicknames kept on the Mac; App Store Connect has no alias field) |
| Customer reviews | yes | yes, with rating summary and filters | done |
| Review reply, reply signature, review link | yes | yes | done |
| Submissions: create, add version or event, submit, cancel | yes | create with version, submit, cancel, full history | done (10.3: Add to New Submission on an event) |
| In-app events: create, duplicate, localize, assets, archive | yes | create, text per language, submit, delete | partial (3.1: duplicate through asc, archive kept on the Mac since App Store Connect has none; assets todo) |
| In-app purchases: list, edit, localize | yes | price and proceeds, create, rename, text per language, add to submission, delete | done |
| IAP and subscription pricing: plan, set, schedule, equalize | yes | app price and proceeds, set app price from a date, set IAP price, subscription price for every country from a US base (equalize) | yes |
| Subscriptions and groups, offers (intro, promo, win-back, codes) | yes | groups and subscriptions with price; introductory, promotional and win-back (free trial) offers; IAP offer codes with one-time code batches | yes |
| Promoted purchases, billing grace period | yes | promote switch per purchase, grace period on or off, length, renewal type | yes |
| Availability and remove from sale | yes | count, per-country switches, everywhere, remove from sale | done |
| Multiple accounts, switch active account | yes | account menu over asc profiles | done |
| Account setup flow (API key, issuer) | yes | Add Account sheet, offered on first run | done |
| Setup export and import file (.helm-setup) | yes | no, on purpose | skip: it would copy a private key around; `asc auth export-to-config` moves a key |
| Command line tool for agents (helm-asc) | yes | MCP server over asc | done (MCP instead of a CLI; asc is the CLI) |
| Agent skill pack | yes | hermes-status, hermes-ship | done |
| App intents and Shortcuts | yes | Get App Store Status, Get One App's Status | done (3.0) |
| Menu bar status and notifications on state change | yes | menu bar list of every app not live yet, a notification on each review-state move, 15-minute refresh | done (3.0) |
| Agreement banner (Apple license updated) | yes | banner on the app list from asc web agreements status | done (3.1) |
| Datasets and charts | yes | last month's downloads, redownloads and proceeds per app from the sales summary | done (9.0: monthly charts on Timeline and Sales) |
| Free tier counter and Pro license | yes | n/a | skip, Hermes is free or $1 |

## Version plan

Each version closes a block of rows above and refreshes the matrix.

- 0.2 landing, brand kit, design system, font, icon (done: hermes.jaybulb.com, Hermes Sans, Hermes.icon, row hover)
- 0.3 version detail: edit, create, ship, reject, review info (done: all writes confirm the exact asc command; read-only mode on by default)
- 0.4 localizations editor with bulk upload and download (done: Metadata tab, .strings export, import validated by --dry-run first)
- 0.5 screenshots and previews (done: Media tab, thumbnails from Apple's CDN, hover delete, uploads checked with --dry-run)
- 0.6 builds and TestFlight write actions (done)
- 0.6.1 app icons for unreleased apps from the latest build's iconAssetToken (done)
- 0.7 rename to Hermes (done)
- 0.8 reviews: reply and signature (done)
- 0.9 submissions (done: Submissions tab, outcomes, rejections-only filter, two-step create)
- 1.0 first major (done: every tab QA'd, 4 bugs fixed, 5 tests and CI, notarized DMG, MCP server, two skills, whitepaper, security, architecture)
- 1.1 in-app events (done: Events tab)
- 1.2 in-app purchases (done)
- 1.3 subscriptions (done, inside the Purchases tab)
- 1.4 pricing (done: App Price in the Purchases tab, IAP price)
- 1.5 availability (done)
- 1.6 offer codes and promoted purchases (done)
- 2.3 light mode and Appearance setting (done)
- 2.4 brand polish (done): feather quotes in Hermes Sans, thicker wing, a two-feather favicon for 16 px
- 2.5 subscription prices for every country, introductory, promotional and win-back offers, grace period (done)
- 2.6 blue brand from clrs.cc and a detailed wing icon with Icon Composer glass (done)
- 2.7 Hermes Sans rebuilt on Inter for SF-like proportional spacing, AA contrast accent, amber review state, brand kit page, 1878 Hermes engraving in a parallax hero (done)
- 2.0 multiple accounts and setup flow (done; full QA passed, 5 tests green)
- 3.0 menu bar, notifications, Shortcuts, agent skills (done: menu bar extra, review-state notifications behind a Settings toggle, two Shortcuts actions, hermes-resolve skill, MCP over HTTP)
- 4.0 release checklist and sales (done: asc validate for every version not live yet, its fix steps in order, on the Status tab; last month's downloads, redownloads and proceeds per app). Parity read against the matrix: everything Helm does is here except event assets, adding an event to a submission, and charts over time. A visual side-by-side with Helm is still to do when Joshua is at the Mac.
- 5.0 fleet grid and release timeline (done: grid toggle on the app list, Timeline tab). Review-time estimates wait for a decision date: asc review history has the submit date only.
- 6.0 Xcode Cloud runs (done: workflows, last five runs, Start Build behind a confirm)
- 7.0 keyword tools (done: Keywords tab on asc's audit, words repeated from the name or subtitle flagged; tab overflow folds into More)
- 7.1 Cover Flow (done: third view of the app list, icons tilt on either side of the centred app over flat reflections; Joshua asked)
- 8.0 screenshot framing (done: Frame sheet in Media, any device asc knows, title and subtitle, solid background; needs Koubou installed)
- 9.0 charts over time (done: versions per month by outcome on Timeline, six months of downloads in Sales)
- 10.0 iPhone and iPad companion (done: iPad split view, phone grid, versions chart, iPad in every orientation; QA'd in the iPad Air 13-inch simulator against the real account)
- then bump the matrix to 1:1 and keep going to 100 with polish, speed and the things Helm lacks

## Long plan

A plan, not a promise. Versions climb one block at a time; majors get the full QA pass.

- 2.x: close the Helm gaps. Left: TestFlight aliases, event duplicate, assets and archive, the agreement banner, datasets and charts.
- 3.0: menu bar status, a notification when any app changes review state, Shortcuts. Declare 1:1 with Helm after a side-by-side QA.
- 4 to 9: past Helm. Release checklist from `asc validate`, sales and analytics, Xcode Cloud runs, keyword tools, screenshot framing, a fleet grid of every app at once, a release timeline, review-time estimates from your own history.
- 10 to 19: iPhone and iPad companion with the same status and notifications, widgets, a watch complication.
- 20 to 49: live updates from App Store Connect webhooks instead of polling, GitHub Actions status next to builds, teams with shared notes.
- 50 to 99: speed, accessibility, every language, the Mac App Store listing at $0.99.
- 100: ship the whole fleet from one window without opening a browser.
- 1000: no plan that far. Past 100 the number is the loop counting, and the work is whatever the last 100 versions taught us.

## Beyond Helm

Shipped: a running indicator for long writes like uploads, read-only mode (Settings), every write shows its asc command before it runs, QA launch arguments `-selectApp <id> -tab <name> -openVersion first`.


Ideas that Helm does not have: rejection history in one place (shipped 0.9), release checklist from `asc validate`, price heat map by territory, Xcode Cloud status, analytics and sales from `asc analytics`.
