<img src="icon.svg" width="80" alt="Talaria">

![version](https://img.shields.io/badge/version-0.2.0-a8441f) ![license](https://img.shields.io/badge/license-MIT-a8441f)

**[talaria.jaybulb.com](https://talaria.jaybulb.com)**

App Store Connect is a website built for one app at a time. Talaria is a Mac app built for all of them at once.

It is named for the talaria, the winged sandals of Hermes, messenger of the gods.

## Features

Every app in one list, with its icon and the live version on each platform. A dot says where each one stands: on sale, in review, rejected or still being prepared.

Open an app for its release status, the next thing to do and anything blocking it. Tabs show versions, builds, TestFlight groups, customer reviews and in-app purchases.

Talaria drives the [asc](https://github.com/rorkai/App-Store-Connect-CLI) command line tool, so your API key stays on your Mac and anything in the window is a command you can script.

## Build

```sh
brew install xcodegen asc
asc auth login --name MyKey --key-id KEY_ID --issuer-id ISSUER_ID --private-key AuthKey.p8
xcodegen generate && open Talaria.xcodeproj
```

The landing is in `landing/`. `./deploy.sh` copies the brand files in and deploys it. The roadmap and the feature-by-feature comparison are in `roadmap.md`.
