<img src="icon.svg" width="80" alt="Hermes">

![version](https://img.shields.io/badge/version-1.4.0-a8441f) ![license](https://img.shields.io/badge/license-MIT-a8441f) ![tests](https://github.com/nulljosh/hermes/actions/workflows/test.yml/badge.svg)

**[hermes.jaybulb.com](https://hermes.jaybulb.com)**

App Store Connect is a website built for one app at a time. Hermes is a Mac app built for all of them at once.

It is named for Hermes, messenger of the gods and patron of merchants, who carried things past every gate.

## Features

Every app in one list, with its icon and the live version on each platform. A dot says where each one stands: on sale, in review, rejected or still being prepared.

Open an app for its release status, the next thing to do and anything blocking it. Tabs show versions, builds, TestFlight groups, customer reviews and in-app purchases.

Hermes drives the [asc](https://github.com/rorkai/App-Store-Connect-CLI) command line tool, so your API key stays on your Mac and anything in the window is a command you can script.

## Get it

[Download Hermes.dmg](https://github.com/nulljosh/hermes/releases/latest/download/Hermes.dmg), signed and notarized by Apple. It needs the [asc](https://github.com/rorkai/App-Store-Connect-CLI) tool signed in to your account.

## Agents

`mcp/server.py` is an MCP server with the same reads plus review replies and submissions, read-only unless `HERMES_ALLOW_WRITES=1`:

```sh
claude mcp add hermes -- uv run ~/Documents/Code/hermes/mcp/server.py
```

`skills/hermes-status` reports where every app stands. `skills/hermes-ship` walks one version to App Review and asks before each write.

## Build

```sh
brew install xcodegen asc
asc auth login --name MyKey --key-id KEY_ID --issuer-id ISSUER_ID --private-key AuthKey.p8
xcodegen generate && open Hermes.xcodeproj
./scripts/release.sh   # signed, notarized dist/Hermes.dmg
```

The landing is in `landing/`. `./deploy.sh` copies the brand files in and deploys it. The roadmap and the feature-by-feature comparison with Helm are in `docs/roadmap.md`. How it works is in `docs/WHITEPAPER.md`.
