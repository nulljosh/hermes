<img src="icon.svg" width="80" alt="Hermes">

![version](https://img.shields.io/badge/version-2.9.0-0074D9) ![license](https://img.shields.io/badge/license-MIT-0074D9) ![tests](https://github.com/nulljosh/hermes/actions/workflows/test.yml/badge.svg)

**[hermes.jaybulb.com](https://hermes.jaybulb.com)**

App Store Connect is a website built for one app at a time. Hermes is a Mac app built for all of them at once.

## Features

Every app in one list, with its icon, its live version on each platform and where it stands in review. Open one for versions, metadata, screenshots, builds, TestFlight, reviews, submissions, events, prices and purchases. Every change shows the exact command and asks first.

When Apple rejects an app, Resolve All reads the rejection, checks the facts (what App Review already approved, how many builds, how much of the code is the app's own) and writes the reply on your Mac's own Apple Intelligence model. No placeholders, nothing leaves the Mac, and nothing sends until you say so.

Hermes runs on the [asc](https://github.com/rorkai/App-Store-Connect-CLI) tool, so your API key stays on your Mac.

## Get it

[Download Hermes.dmg](https://github.com/nulljosh/hermes/releases/latest/download/Hermes.dmg), signed and notarized. Sign in to `asc` first.

## Agents

The Hermes MCP server gives agents the same view. One line, no clone, read only unless `HERMES_ALLOW_WRITES=1`:

```sh
claude mcp add hermes -- uv run https://raw.githubusercontent.com/nulljosh/hermes/main/mcp/server.py
```

Run it as a local API instead with `uv run mcp/server.py --http`: the same tools at `127.0.0.1:8787/mcp`, and plain JSON at `/api/<tool>`, such as `/api/app_facts?app_id=123`. Three skills ship in `skills/`: `hermes-status`, `hermes-ship` and `hermes-resolve`.

Everything else is at [hermes.jaybulb.com/docs](https://hermes.jaybulb.com/docs).

## Build

```sh
brew install xcodegen asc
asc auth login --name MyKey --key-id KEY_ID --issuer-id ISSUER_ID --private-key AuthKey.p8
xcodegen generate && open Hermes.xcodeproj
./scripts/release.sh   # signed, notarized dist/Hermes.dmg
```

The roadmap is `docs/roadmap.md`. How it works is `docs/WHITEPAPER.md`.
