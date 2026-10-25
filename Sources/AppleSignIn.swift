import SwiftUI
import AppKit

// Apple web sign-in for the asc web commands (Resolve All, Resolution Center replies).
// asc asks for the 2FA code by running TwoFactor.script, which leaves a marker file and waits;
// Hermes sees the marker, asks for the code, and writes it back. Hermes never stores the code or the password.
enum TwoFactor {
    static let dir = URL.cachesDirectory.appendingPathComponent("Hermes/2fa")
    static var waiting: URL { dir.appendingPathComponent("waiting") }
    static var code: URL { dir.appendingPathComponent("code") }

    /// Written once per launch. Waits up to three minutes, and gives up early if the prompt is cancelled.
    static let script: String = {
        let path = dir.appendingPathComponent("code-command.sh")
        let d = dir.path.replacingOccurrences(of: "'", with: "'\\''")
        let body = """
        #!/bin/sh
        # Written by Hermes. asc runs this when Apple asks for a 2FA code.
        d='\(d)'
        rm -f "$d/code"; touch "$d/waiting"
        # A code Apple texts to a phone that forwards to Messages fills itself in; the prompt covers the rest.
        /opt/homebrew/bin/asc web auth messages-code --since 20s --timeout 175s > "$d/code.sms" 2>/dev/null && mv "$d/code.sms" "$d/code" &
        m=$!
        trap 'kill $m 2>/dev/null; rm -f "$d/code.sms"' EXIT
        i=0
        while [ $i -lt 600 ]; do
          if [ -s "$d/code" ]; then cat "$d/code"; rm -f "$d/code" "$d/waiting"; exit 0; fi
          [ -f "$d/waiting" ] || exit 1
          i=$((i+1)); sleep 0.3
        done
        rm -f "$d/waiting"; exit 1

        """
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? body.write(to: path, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: path.path)
        return path.path
    }()

    /// Runs for the life of the window. A modal alert, so it shows over any open sheet.
    @MainActor static func watch() async {
        while !Task.isCancelled {
            if FileManager.default.fileExists(atPath: waiting.path) {
                let a = NSAlert()
                a.messageText = "Apple sign-in"
                a.informativeText = "Enter the 6-digit code Apple just sent to your devices. If you got it by text, enter that one."
                let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
                field.placeholderString = "123 456"
                a.accessoryView = field
                a.addButton(withTitle: "Sign In")
                a.addButton(withTitle: "Cancel")
                a.window.initialFirstResponder = field
                // The script removes the marker when Messages supplied the code or asc gave up: close the prompt then.
                let gone = Timer(timeInterval: 0.5, repeats: true) { _ in
                    if !FileManager.default.fileExists(atPath: waiting.path) { NSApp.abortModal() }
                }
                RunLoop.main.add(gone, forMode: .modalPanel)
                defer { gone.invalidate() }
                let answer = a.runModal()
                if answer == .abort { continue }
                if answer == .alertFirstButtonReturn, case let c = field.stringValue.filter(\.isNumber), c.count == 6 {
                    try? c.write(to: code, atomically: true, encoding: .utf8)
                } else {
                    try? FileManager.default.removeItem(at: waiting)
                }
                // Let the script pick the code up before looking again, so the prompt never shows twice.
                try? await Task.sleep(for: .seconds(2))
            }
            try? await Task.sleep(for: .milliseconds(400))
        }
    }
}

enum AppleWeb {
    struct Status: Decodable { let authenticated: Bool; let passwordStored: Bool?; let appleId: String? }

    static func status() async -> Status? {
        guard let d = try? await ASC.exec("/opt/homebrew/bin/asc", ["web", "auth", "status"], timeout: 30) else { return nil }
        return try? JSONDecoder().decode(Status.self, from: d)
    }

    /// An asc error that means the Apple web session is gone, not that one app failed.
    static func isSessionError(_ e: Error) -> Bool {
        let m = e.localizedDescription.lowercased()
        return m.contains("web session") || m.contains("session expired") || m.contains("2fa required") || m.contains("web auth login")
    }

    /// Apple is throttling sign-ins: when asc will try again. Every attempt counts toward Apple's limit, so callers wait instead of retrying.
    static func throttledUntil(_ e: Error) -> Date? {
        let m = e.localizedDescription
        guard m.contains("throttl") || m.contains("not sign in automatically") || m.contains("status 503") else { return nil }
        if let r = m.range(of: #"(?<=until |before )\d{4}-\d{2}-\d{2}T[0-9:.]+Z"#, options: .regularExpression),
           let d = ISO8601DateFormatter().date(from: String(m[r]).replacingOccurrences(of: #"\.\d+"#, with: "", options: .regularExpression)) { return d }
        return .now.addingTimeInterval(600)
    }

    /// The password goes to asc for this one run; asc keeps it in its own keychain entry after a good sign-in.
    static func signIn(appleID: String, password: String) async throws {
        _ = try await ASC.exec("/opt/homebrew/bin/asc", ["web", "auth", "login", "--apple-id", appleID],
                               timeout: 300, env: password.isEmpty ? [:] : ["ASC_WEB_PASSWORD": password])
    }
}

struct AppleSignInSheet: View {
    let close: () -> Void
    @State private var appleID = ""
    @State private var password = ""
    @State private var stored = false
    @State private var busy = false
    @State private var note = ""

    var body: some View {
        Form {
            Text("Resolve All and Resolution Center replies use your Apple Account. Hermes asks for the two-factor code when Apple sends one, and keeps neither the code nor the password.")
                .font(Theme.font(11)).foregroundStyle(Theme.muted)
            TextField("Apple Account", text: $appleID, prompt: Text("name@icloud.com"))
            SecureField(stored ? "Password (saved, leave empty)" : "Password", text: $password)
            if !note.isEmpty { Text(note).foregroundStyle(note == "Signed in." ? Theme.live : Theme.bad).textSelection(.enabled) }
            HStack {
                Button("Close", action: close).keyboardShortcut(.cancelAction)
                Spacer()
                if busy { ProgressView().controlSize(.small) }
                Button("Sign In") { Task { await signIn() } }
                    .disabled(busy || appleID.isEmpty || (password.isEmpty && !stored))
                    .keyboardShortcut(.defaultAction)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .task {
            guard let s = await AppleWeb.status() else { return }
            appleID = s.appleId ?? ""; stored = s.passwordStored ?? false
            if s.authenticated { note = "Signed in." }
        }
    }

    func signIn() async {
        busy = true; note = ""
        defer { busy = false }
        do {
            try await AppleWeb.signIn(appleID: appleID, password: password)
            password = ""
            note = await AppleWeb.status()?.authenticated == true ? "Signed in." : "Apple did not finish the sign-in. Try again in a few minutes."
        } catch {
            note = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}
