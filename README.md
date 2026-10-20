<img src="icon.svg" width="80" alt="Hermes">

![version](https://img.shields.io/badge/version-0.8.0-a8441f) ![license](https://img.shields.io/badge/license-MIT-a8441f)

**[hermes.jaybulb.com](https://hermes.jaybulb.com)**

App Store Connect is a website built for one app at a time. Hermes is a Mac app built for all of them at once.

It is named for Hermes, messenger of the gods and patron of merchants, who carried things past every gate.

## Features

Every app in one list, with its icon and the live version on each platform. A dot says where each one stands: on sale, in review, rejected or still being prepared.

Open an app for its release status, the next thing to do and anything blocking it. Tabs show versions, builds, TestFlight groups, customer reviews and in-app purchases.

Hermes drives the [asc](https://github.com/rorkai/App-Store-Connect-CLI) command line tool, so your API key stays on your Mac and anything in the window is a command you can script.

## Build

```sh
brew install xcodegen asc
asc auth login --name MyKey --key-id KEY_ID --issuer-id ISSUER_ID --private-key AuthKey.p8
xcodegen generate && open Hermes.xcodeproj
```

The landing is in `landing/`. `./deploy.sh` copies the brand files in and deploys it. The roadmap and the feature-by-feature comparison are in `roadmap.md`.
