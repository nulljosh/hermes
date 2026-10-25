#!/bin/sh
# Run Hermes' Writer (Apple's on-device model, else Ollama) on one rejection from the terminal, without the app.
#   scripts/try-writer.sh <app name> <reasons> <facts.txt> <apple.txt> [replied]
set -e
cd "$(dirname "$0")/.."
out="${TMPDIR:-/tmp}/hermes-writer"; mkdir -p "$out"
cat > "$out/main.swift" <<'SWIFT'
import Foundation
let a = CommandLine.arguments
let d = try await Writer.write(app: a[1], reasons: a[2], replied: a.count > 5 && a[5] == "yes",
                               facts: String(contentsOfFile: a[3], encoding: .utf8), apple: String(contentsOfFile: a[4], encoding: .utf8))
print("Reply:\n\(d.reply)\n\nIssue: \(d.title)\n\(d.body)")
SWIFT
swiftc -O -enable-bare-slash-regex -o "$out/writer" Sources/Writer.swift "$out/main.swift"
"$out/writer" "$@"
