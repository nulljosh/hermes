# Security

Hermes never sees your App Store Connect key. It runs the `asc` command line tool, which keeps the key in its own config or your Keychain. Hermes stores only two preferences on your Mac: read-only mode and your review reply signature.

Nothing leaves your Mac except what `asc` sends to Apple, and what the app list fetches from Apple's public iTunes lookup for icons.

Read-only mode is on by default and makes `asc` refuse every write before it is sent. The MCP server is read-only unless you set `HERMES_ALLOW_WRITES=1`.

Found a problem? Email trommatic@icloud.com with the subject "Hermes security". Please do not open a public issue for it.
