# Hermes

Native SwiftUI Mac app for App Store Connect. A feature-for-feature match for Helm (/Applications/Helm.app, com.modumhq.Helm 2.3.9) with its own brand and code. Never copy Helm's assets, datasets, text or code.

- Data comes from the `asc` CLI (`Sources/ASC.swift`), run with ASC_BYPASS_KEYCHAIN=1. No direct API client.
- xcodegen `project.yml`; the xcodeproj is generated and ignored. Build: `xcodebuild -scheme Hermes -configuration Release -derivedDataPath build`.
- Design tokens: `brand/tokens.css`, mirrored in `Sources/Theme.swift`. Font: Hermes Sans from `scripts/gen_font.py` (Inter, OFL). Icon: `Hermes.icon` via the brand generator.
- Landing: `landing/`, Worker `hermes` at hermes.jaybulb.com, `./deploy.sh`.
- `docs/roadmap.md` holds the parity matrix. Versions follow honest semver: features are minors, fixes are patches, a major only on Joshua's call. QA the app at every major version.
- Resolve All: `Sources/Facts.swift` builds each app's fact sheet (asc history, builds, GitHub files via gh), `Sources/Writer.swift` drafts on Apple's on-device model, then Ollama. Mirror any change in `mcp/server.py` (`app_facts`) so the app and the MCP agree. Try the writer from the terminal with `scripts/try-writer.sh`.
- Never `open` a fresh build headless to test (`-resolveAll YES`): every new build is a new app to macOS and sets off privacy prompts. Compile, then test through the MCP or `scripts/try-writer.sh`.
- Store names lag renames (Thinkpond is Melete, Sidewise became Bugle, Danae was a probe leftover on Atlin). Check the listing name before replying.
- Mutations go through `asc` with --dry-run first, and never against live apps without Joshua's yes.

## The loop

The loop works through the open rows of `docs/roadmap.md`. Current state and the next items are in `docs/LOOP-HANDOFF.md`. Read it before any loop iteration.
