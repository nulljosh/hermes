# Hermes roadmap

Goal: a native Mac app for App Store Connect that matches Helm 2.3.9 feature for feature, with its own brand and code. Hermes drives the `asc` CLI, so auth and API coverage come from there.

Reference: `/Applications/Helm.app` (bundle id com.modumhq.Helm). Re-check the matrix every version. The truth for Helm's surface is its `helm-asc` command map in `Contents/Resources/AgentSkill_AgentSkill.bundle`.

## Parity matrix (v1.0.0)

| Area | Helm | Hermes | Status |
|---|---|---|---|
| App list, icons, search, refresh | yes | yes | done |
| Per-platform version and state dot | yes | yes | done |
| Two-pane welcome window | yes | yes | done |
| Release status and next action | yes | yes | done (Hermes adds blockers) |
| Version list | yes | yes | done |
| Create version, edit version, ship, reject | yes | create, edit, submit, release, delete, cancel submission | done |
| Review info (notes, demo account, attachments) | yes | contact, notes, demo account | partial (attachments todo) |
| Localizations: list, edit, bulk download and upload | yes | yes, plus App Info name and subtitle, character limits | done |
| Screenshots: view, upload, delete, download | yes | yes | done |
| App previews: view, upload, delete, frame time | yes | view, upload, delete | partial (poster frame todo) |
| Builds list | yes | yes | done |
| Build upload, expire, attach to version, submit for beta review | yes | expire, attach, add to group, What to Test | partial (upload, beta review submit todo) |
| TestFlight groups | yes | yes | done |
| TestFlight group create, edit, testers, add builds, aliases | yes | create, edit, delete, testers, invite, add builds, copy public link | partial (aliases todo) |
| Customer reviews | yes | yes, with rating summary and filters | done |
| Review reply, reply signature, review link | yes | yes | done |
| Submissions: create, add version or event, submit, cancel | yes | create with version, submit, cancel, full history | partial (add event lands with in-app events) |
| In-app events: create, duplicate, localize, assets, archive | yes | no | todo |
| In-app purchases: list, edit, localize | yes | read only | partial |
| IAP and subscription pricing: plan, set, schedule, equalize | yes | no | todo |
| Subscriptions and groups, offers (intro, promo, win-back, codes) | yes | no | todo |
| Promoted purchases, billing grace period | yes | no | todo |
| Availability and remove from sale | yes | no | todo |
| Multiple accounts, switch active account | yes | no (one asc profile) | todo |
| Account setup flow (API key, issuer) | yes | no, uses asc auth | todo |
| Setup export and import file (.helm-setup) | yes | no | todo |
| Command line tool for agents (helm-asc) | yes | MCP server over asc | done (MCP instead of a CLI; asc is the CLI) |
| Agent skill pack | yes | hermes-status, hermes-ship | done |
| App intents and Shortcuts | yes | no | todo |
| Menu bar status and notifications on state change | yes | no | todo |
| Agreement banner (Apple license updated) | yes | no | todo |
| Datasets and charts | yes | no | check what these are |
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
- 1.1 in-app events
- 1.2 to 1.9 IAP and subscriptions with pricing and offers
- 2.0 multiple accounts, setup flow, export and import
- 3.0 menu bar, notifications, Shortcuts, CLI wrapper, agent skill
- then bump the matrix to 1:1 and keep going to 100 with polish, speed and the things Helm lacks

## Beyond Helm

Shipped: read-only mode (Settings), every write shows its asc command before it runs, QA launch arguments `-selectApp <id> -tab <name> -openVersion first`.


Ideas that Helm does not have: rejection history in one place (shipped 0.9), release checklist from `asc validate`, price heat map by territory, Xcode Cloud status, analytics and sales from `asc analytics`.
