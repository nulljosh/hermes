# Hermes Technical Whitepaper

**v4.0.0** | October 2026

Hermes is a native Mac app for App Store Connect. It shows every app on an account in one window, with the state of each platform's newest version, and lets you edit versions, store text, screenshots, builds, TestFlight groups, review replies and submissions without opening Apple's website. It holds no API client of its own. Every screen is a call to the open source `asc` command line tool, so the key stays on the Mac and anything the window does is a command a script or an agent can run.

## The core idea: a window over a command line

Each read is `asc <command> --output json`, decoded leniently. Lists come back as `data` or `items`, attributes are scalars of any type, and missing fields become empty rather than errors. The app list loads names first, then fills versions and icons four calls at a time, because sixty `asc` processes at once made some fail.

Writes are built as a `PendingCommand`: a title and the exact arguments. Before anything runs, a dialog shows the command line as you could paste it. Two-step writes (create a submission, then add a version to it) carry a second command that takes the first one's new id.

Read-only mode is on by default. It passes `--read-only` to every call, and `asc` refuses any POST, PATCH or DELETE before it leaves the machine. Uploads go through `--dry-run` first and only then ask.

## Resolve All

Rejections live in Resolution Center threads, which only Apple's web session can read, so Hermes reads them with `asc web review show`. For each app it builds a fact sheet before any model sees the letter: the version history and which versions App Review already approved, the builds uploaded and when, and from GitHub the app's own Swift files and how many are byte-identical to files in the other apps on the account (git blob SHAs, one tree call per repo, cached a day). In a monorepo the app is only its own folders, found from the bundle id in each project.yml.

`Sources/Writer.swift` writes the reply on Apple's on-device model (Foundation Models), or a local Ollama model when Apple Intelligence is off. Nothing leaves the Mac and no child process runs. The model's context is about 4,000 tokens, so it gets one task at a time. Apple's nine-question 4.3 follow-up is split into its questions, and each one is pointed at the fact that answers it. A plain 4.3(a) gets the house reply: the model's two sentences on what the app is, then the checked facts word for word, then a question about which apps were found similar. Sentences that repeat an earlier answer, or claim a change nobody made, are cut. Send stays off until Joshua confirms, and a send is never retried.

## Menu bar, notifications and Shortcuts

One shared store feeds the window, the menu bar and Shortcuts, so they never disagree. While Hermes runs it reloads every 15 minutes. After each load it compares every app's state per platform with the last load and, if the Settings toggle is on, posts a notification for each real move (a version seen for the first time is not a move). Permission to notify is asked for only when that toggle is turned on. Two App Intents, Get App Store Status and Get One App's Status, return the same read as text for Shortcuts and Siri.

## Release checklist and sales

The Status tab runs `asc validate` for each version that is not live yet and shows its remediation plan in order, blocking steps first in red. Validate never writes, so it runs in read-only mode. Below it, last month's downloads, redownloads and proceeds come from Apple's monthly sales summary, downloaded once per month for the whole account and cached; product types starting with 1 count as downloads, 3 as redownloads, and updates (7) are left out. Reading sales needs an App Store Connect key with the Finance or Sales role, and the section says so when the key lacks it.

## Icons

Live apps use their App Store artwork from the iTunes lookup. Apps that are not on sale yet use the icon Apple extracted from their newest build (`iconAssetToken`). Anything else gets a letter tile.

## Agents

`mcp/server.py` exposes the same reads as MCP tools, plus Resolve All (`open_rejections`, `app_facts`, `saved_drafts`) and three writes (reply to a customer review, submit for review, send a Resolution Center reply), read-only unless `HERMES_ALLOW_WRITES=1`. It runs over stdio, or with `--http` on 127.0.0.1:8787 as MCP at `/mcp` and a JSON API at `/api/<tool>`. Three skills, `hermes-status`, `hermes-ship` and `hermes-resolve`, describe the release report, the path from build to App Review, and answering rejections.

## Brand

A wing from Hermes' sandals on a blue tile (clrs.cc), built as an Icon Composer bundle. The type is Hermes Sans, Inter renamed under the SIL Open Font License. Colours and spacing live in `brand/tokens.css` and are mirrored in `Sources/Theme.swift`.

## Distribution

`scripts/release.sh` archives with the Developer ID certificate and hardened runtime, wraps the app in a drag-to-Applications disk image, notarizes it with Apple, staples the ticket and checks it with Gatekeeper.

## Limits

It needs `asc` installed and signed in. One account at a time. In-app purchase editing, pricing, offers, in-app events and multiple accounts are not built yet; `docs/roadmap.md` tracks them against Helm.

MIT License, 2026 Joshua Trommel.
