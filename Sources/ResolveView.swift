import SwiftUI

// Resolve All: read every open rejection, have Claude draft the Resolution Center reply and a GitHub issue
// for each, edit them in one sheet, then send. Replies go through asc's web session, so this is Mac only.

/// What `asc web review show --plain-text` returns, trimmed to what Resolve All reads.
struct ReviewShow: Decodable {
    struct Version: Decodable { let version: String? }
    struct Submission: Decodable { let state: String?; let appStoreVersionForReview: Version? }
    struct Actor: Decodable { let actorType: String? }
    struct Message: Decodable { let createdDate: String; let messageBodyPlain: String?; let fromActor: Actor? }
    struct Reason: Decodable { let reasonSection: String?; let reasonDescription: String? }
    struct Rejection: Decodable { let reasons: [Reason]? }
    struct Info: Decodable { let id: String; let canDeveloperAddNote: Bool? }
    struct Thread: Decodable { let thread: Info; let messages: [Message]?; let rejections: [Rejection]? }
    let submission: Submission?
    let threads: [Thread]?

    /// The thread waiting on us: the submission still has unresolved issues and Apple wrote last.
    /// `waiting` is true when we already replied and Apple owes the answer.
    func open() -> (thread: Thread, apple: String, replied: Bool, waiting: Bool)? {
        guard submission?.state == "UNRESOLVED_ISSUES" else { return nil }
        for t in threads ?? [] where t.thread.canDeveloperAddNote != false {
            let msgs = (t.messages ?? []).sorted { $0.createdDate > $1.createdDate }
            guard let last = msgs.first else { continue }
            let apple = msgs.first { $0.fromActor?.actorType == "APPLE" }?.messageBodyPlain ?? ""
            let replied = msgs.contains { $0.fromActor?.actorType != "APPLE" }
            return (t, apple, replied, last.fromActor?.actorType != "APPLE")
        }
        return nil
    }

    var reasons: [String] {
        (threads ?? []).flatMap { $0.rejections ?? [] }.flatMap { $0.reasons ?? [] }
            .map { [$0.reasonSection, $0.reasonDescription].compactMap { $0 }.joined(separator: " ") }
    }
}

struct Resolution: Identifiable {
    let app: ASCApp
    let thread: String
    let version: String
    let reasons: [String]
    let apple: String
    let replied: Bool
    var reply = ""
    var issueTitle = ""
    var issueBody = ""
    var repo: String
    var include = true
    var receipt: String?
    var id: String { thread }
    /// Square brackets mark facts only Joshua knows ("[what changed in build 4]"). Nothing sends until they are filled.
    var unfilled: Bool { reply.contains("[") || issueBody.contains("[") }
}

struct ResolveView: View {
    let store: Store
    var close: () -> Void
    @State private var rows: [Resolution] = []
    @State private var waiting: [String] = []
    @State private var unread: [String] = []
    @State private var phase = "Reading rejections"
    @State private var busy = true
    @State private var confirming = false
    @State private var signInNeeded = false
    @State private var signingIn = false

    /// Apps whose newest version on some platform was rejected.
    var rejected: [ASCApp] { store.apps.filter { (store.versions[$0.id] ?? []).contains { $0.state.contains("REJECT") } } }
    var sending: [Resolution] { rows.filter { $0.include && (!$0.reply.isEmpty || !$0.issueTitle.isEmpty) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Resolve All").font(Theme.display(28))
                Spacer()
                if busy { ProgressView().controlSize(.small) }
                Text(phase).foregroundStyle(Theme.muted)
            }
            .padding(16)
            Divider().overlay(Theme.line)
            ScrollView {
                VStack(spacing: 12) {
                    ForEach($rows) { $r in ResolutionCard(r: $r, icon: store.icons[r.app.id]) }
                    if !waiting.isEmpty {
                        Text("Waiting on Apple: " + waiting.joined(separator: ", ")).foregroundStyle(Theme.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if signInNeeded {
                        HStack {
                            Text("Sign in to your Apple Account to read the rejections.").foregroundStyle(Theme.muted)
                            Spacer()
                            Button("Sign In") { signingIn = true }
                        }
                    }
                    ForEach(unread, id: \.self) { Text("Could not read " + $0).foregroundStyle(Theme.bad).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading) }
                }
                .padding(16)
            }
            Divider().overlay(Theme.line)
            HStack {
                if ASC.readOnly { Text("Read-only is on. Turn it off in Settings to send.").foregroundStyle(Theme.muted) }
                else if sending.contains(where: \.unfilled) { Text("Fill in the [brackets] first.").foregroundStyle(Theme.pending) }
                Spacer()
                Button("Close", action: close).keyboardShortcut(.cancelAction)
                Button("Send All (\(sending.count))") { confirming = true }
                    .keyboardShortcut(.defaultAction)
                    .disabled(busy || ASC.readOnly || sending.isEmpty || sending.contains(where: \.unfilled))
            }
            .padding(16)
        }
        .frame(width: 760, height: 640)
        .background(Theme.bg)
        .task { await scan() }
        .onDisappear { SavedDrafts.save(rows) }
        .sheet(isPresented: $signingIn, onDismiss: { Task { await scan() } }) { AppleSignInSheet { signingIn = false }.font(Theme.font(13)) }
        .confirmationDialog("Send \(sending.count) to Apple and GitHub?", isPresented: $confirming, titleVisibility: .visible) {
            Button("Send All") { Task { await send() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(sending.map { r in
                [r.reply.isEmpty ? nil : "asc web review reply --thread-id \(r.thread) --confirm   (\(r.app.name))",
                 r.issueTitle.isEmpty || r.repo.isEmpty ? nil : "gh issue create --repo \(r.repo) --title \"\(r.issueTitle)\""]
                    .compactMap { $0 }.joined(separator: "\n")
            }.joined(separator: "\n"))
        }
    }

    func scan() async {
        // asc refuses to follow symlinks, and the temp folder sits behind /var -> /private/var. Caches has none.
        let dir = URL.cachesDirectory.appendingPathComponent("Hermes/review")
        var found: [Resolution] = []
        busy = true; signInNeeded = false; unread = []; waiting = []
        // Opened at launch, the list may still be loading; rejections are read off it.
        for _ in 0..<200 where store.loading || (store.apps.isEmpty && store.error == nil) { try? await Task.sleep(for: .milliseconds(300)) }
        let apps = rejected
        var i = 0, pauses = 0, healed = false
        while i < apps.count, !Task.isCancelled {
            let app = apps[i]
            phase = "Reading \(app.name) (\(i + 1) of \(apps.count))"
            // ponytail: one app at a time with a short gap, so nine reads never look like a burst to Apple.
            if i > 0 { try? await Task.sleep(for: .seconds(2)) }
            i += 1
            do {
                let data = try await ASC.run(["web", "review", "show", "--app", app.id, "--plain-text",
                                              "--out", dir.appendingPathComponent(app.id).path], timeout: 240)
                let show = try JSONDecoder().decode(ReviewShow.self, from: data)
                guard let o = show.open() else { continue }
                if o.waiting { waiting.append(app.name); continue }
                found.append(Resolution(app: app, thread: o.thread.thread.id, version: show.submission?.appStoreVersionForReview?.version ?? "",
                                        reasons: show.reasons, apple: o.apple, replied: o.replied,
                                        repo: UserDefaults.standard.string(forKey: "repo." + app.id) ?? ""))
            } catch {
                // Apple paused sign-ins: wait it out and read the same app again, rather than spend more attempts.
                if let until = AppleWeb.throttledUntil(error), pauses < 3 {
                    pauses += 1
                    phase = "Apple paused sign-ins. Reading again at \(until.formatted(date: .omitted, time: .shortened))"
                    try? await Task.sleep(for: .seconds(max(5, until.timeIntervalSinceNow + 15)))
                    i -= 1; continue
                }
                // One expired session fails every app the same way: stop and ask once instead of listing it nine times.
                // An expired session signs itself back in once with the saved password; the 2FA code fills from Messages.
                if AppleWeb.isSessionError(error), !healed, Vault.password != nil,
                   let id = await AppleWeb.status()?.appleId ?? UserDefaults.standard.string(forKey: "appleID") {
                    healed = true; phase = "Signing in to Apple"
                    if (try? await AppleWeb.signIn(appleID: id, password: "")) != nil { i -= 1; continue }
                }
                if AppleWeb.isSessionError(error) { signInNeeded = true; break }
                unread.append(app.name + ": " + (error.localizedDescription.split(separator: "\n").first.map(String.init) ?? "failed"))
            }
        }
        rows = found
        if signInNeeded && found.isEmpty { phase = "Apple sign-in needed"; busy = false; return }
        guard !found.isEmpty else { phase = waiting.isEmpty ? "No open rejections." : "Nothing to answer."; busy = false; return }
        rows = SavedDrafts.apply(found)
        let fresh = rows.filter { ($0.reply + $0.issueTitle + $0.issueBody).isEmpty }
        if !fresh.isEmpty {
            guard await Drafter.available else { phase = "Turn on Apple Intelligence or run Ollama to draft replies, or write them yourself."; busy = false; return }
            phase = "Drafting \(fresh.count) replies"
            do {
                let drafted = try await Drafter.draft(fresh)
                rows = rows.map { r in drafted.first { $0.thread == r.thread } ?? r }
            } catch { phase = error.localizedDescription; busy = false; return }
        }
        SavedDrafts.save(rows)
        phase = "\(rows.count) to review"
        busy = false
    }

    /// One app at a time, stopping at the first failure. Never retried: Apple may have taken a write that reported an error.
    func send() async {
        busy = true
        defer { busy = false }
        SavedDrafts.save(rows)
        for i in rows.indices where rows[i].include && rows[i].receipt == nil {
            let r = rows[i]
            phase = "Sending \(r.app.name)"
            var done: [String] = []
            do {
                if !r.reply.isEmpty {
                    _ = try await ASC.run(["web", "review", "reply", "--thread-id", r.thread, "--message", r.reply, "--confirm"], timeout: 120)
                    done.append("Reply sent")
                }
                if !r.issueTitle.isEmpty, !r.repo.isEmpty {
                    UserDefaults.standard.set(r.repo, forKey: "repo." + r.app.id)
                    let gh = "/opt/homebrew/bin/gh"
                    let open = try await ASC.exec(gh, ["issue", "list", "--repo", r.repo, "--state", "open", "--search", "in:title \(r.issueTitle)",
                                                       "--json", "number"], timeout: 60)
                    if String(decoding: open, as: UTF8.self).contains("number") { done.append("Issue already open") }
                    else {
                        let url = try await ASC.exec(gh, ["issue", "create", "--repo", r.repo, "--title", r.issueTitle, "--body", r.issueBody], timeout: 60)
                        done.append("Issue " + String(decoding: url, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                }
                rows[i].receipt = done.joined(separator: ". ")
            } catch {
                rows[i].receipt = (done + ["Stopped: " + error.localizedDescription]).joined(separator: ". ")
                phase = "Stopped at \(r.app.name)"
                return
            }
        }
        phase = "All sent"
    }
}

struct ResolutionCard: View {
    @Binding var r: Resolution
    let icon: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                AppIcon(app: r.app, url: icon, size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(r.app.name) \(r.version)").font(Theme.font(14, .semibold))
                    Text(r.reasons.joined(separator: ", ")).font(Theme.font(11, .medium)).foregroundStyle(Theme.bad)
                }
                Spacer()
                Toggle("Include", isOn: $r.include).toggleStyle(.switch).controlSize(.small).labelsHidden()
            }
            if let receipt = r.receipt {
                Text(receipt).foregroundStyle(receipt.contains("Stopped") ? Theme.bad : Theme.live).textSelection(.enabled)
            }
            DisclosureGroup("What Apple said") {
                Text(r.apple).foregroundStyle(Theme.muted).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
            }
            field("Reply to App Review", $r.reply, height: 110)
            TextField("Issue title", text: $r.issueTitle).textFieldStyle(.roundedBorder)
            field("Issue", $r.issueBody, height: 80)
            TextField("GitHub repo, owner/name (empty skips the issue)", text: $r.repo).textFieldStyle(.roundedBorder)
        }
        .padding(12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 8))
        .opacity(r.include ? 1 : 0.5)
    }

    private func field(_ label: String, _ text: Binding<String>, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(Theme.font(11, .semibold)).foregroundStyle(Theme.muted)
            TextEditor(text: text).font(Theme.font(13)).frame(height: height)
                .scrollContentBackground(.hidden).padding(4)
                .background(Theme.bg, in: RoundedRectangle(cornerRadius: 6))
        }
    }
}
