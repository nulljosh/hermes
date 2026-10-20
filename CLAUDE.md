# Talaria

Native SwiftUI Mac app for App Store Connect. A feature-for-feature match for Helm (/Applications/Helm.app, com.modumhq.Helm 2.3.9) with its own brand and code. Never copy Helm's assets, datasets, text or code.

- Data comes from the `asc` CLI (`Sources/ASC.swift`), run with ASC_BYPASS_KEYCHAIN=1. No direct API client.
- xcodegen `project.yml`; the xcodeproj is generated and ignored. Build: `xcodebuild -scheme Talaria -configuration Release -derivedDataPath build`.
- Design tokens: `brand/tokens.css`, mirrored in `Sources/Theme.swift`. Font: Talaria Sans from `scripts/gen_font.py` (Instrument Sans, OFL). Icon: `Talaria.icon` via the brand generator.
- Landing: `landing/`, Worker `talaria` at talaria.jaybulb.com, `./deploy.sh`.
- `roadmap.md` holds the parity matrix. The loop to v100 is `~/.claude/loops/talaria.md`; QA the app at every major version.
- Mutations go through `asc` with --dry-run first, and never against live apps without Joshua's yes.
