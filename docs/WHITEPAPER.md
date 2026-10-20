# Hermes Technical Whitepaper

**v1.0.0** | October 2026

Hermes is a native Mac app for App Store Connect. It shows every app on an account in one window, with the state of each platform's newest version, and lets you edit versions, store text, screenshots, builds, TestFlight groups, review replies and submissions without opening Apple's website. It holds no API client of its own. Every screen is a call to the open source `asc` command line tool, so the key stays on the Mac and anything the window does is a command a script or an agent can run.

## The core idea: a window over a command line

Each read is `asc <command> --output json`, decoded leniently. Lists come back as `data` or `items`, attributes are scalars of any type, and missing fields become empty rather than errors. The app list loads names first, then fills versions and icons four calls at a time, because sixty `asc` processes at once made some fail.

Writes are built as a `PendingCommand`: a title and the exact arguments. Before anything runs, a dialog shows the command line as you could paste it. Two-step writes (create a submission, then add a version to it) carry a second command that takes the first one's new id.

Read-only mode is on by default. It passes `--read-only` to every call, and `asc` refuses any POST, PATCH or DELETE before it leaves the machine. Uploads go through `--dry-run` first and only then ask.

## Icons

Live apps use their App Store artwork from the iTunes lookup. Apps that are not on sale yet use the icon Apple extracted from their newest build (`iconAssetToken`). Anything else gets a letter tile.

## Agents

`mcp/server.py` exposes the same reads and two writes (reply to a review, submit for review) as MCP tools over stdio, read-only unless `HERMES_ALLOW_WRITES=1`. Two skills, `hermes-status` and `hermes-ship`, describe the release report and the path from build to App Review.

## Brand

A wing from Hermes' sandals on a blue tile (clrs.cc), built as an Icon Composer bundle. The type is Hermes Sans, Instrument Sans renamed under the SIL Open Font License. Colours and spacing live in `brand/tokens.css` and are mirrored in `Sources/Theme.swift`.

## Distribution

`scripts/release.sh` archives with the Developer ID certificate and hardened runtime, wraps the app in a drag-to-Applications disk image, notarizes it with Apple, staples the ticket and checks it with Gatekeeper.

## Limits

It needs `asc` installed and signed in. One account at a time. In-app purchase editing, pricing, offers, in-app events and multiple accounts are not built yet; `docs/roadmap.md` tracks them against Helm.

MIT License, 2026 Joshua Trommel.
