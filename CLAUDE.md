# Hermes

Native SwiftUI Mac app for App Store Connect. A feature-for-feature match for Helm (/Applications/Helm.app, com.modumhq.Helm 2.3.9) with its own brand and code. Never copy Helm's assets, datasets, text or code.

- Data comes from the `asc` CLI (`Sources/ASC.swift`), run with ASC_BYPASS_KEYCHAIN=1. No direct API client.
- xcodegen `project.yml`; the xcodeproj is generated and ignored. Build: `xcodebuild -scheme Hermes -configuration Release -derivedDataPath build`.
- Design tokens: `brand/tokens.css`, mirrored in `Sources/Theme.swift`. Font: Hermes Sans from `scripts/gen_font.py` (Inter, OFL). Icon: `Hermes.icon` via the brand generator.
- Landing: `landing/`, Worker `hermes` at hermes.jaybulb.com, `./deploy.sh`.
- `docs/roadmap.md` holds the parity matrix. The loop to v100 is `~/.claude/loops/hermes.md`; QA the app at every major version.
- Mutations go through `asc` with --dry-run first, and never against live apps without Joshua's yes.

## The loop

The loop to v100 runs from `~/.claude/loops/hermes.md`. Current state and the next items are in `docs/LOOP-HANDOFF.md`. Read it before any loop iteration.
