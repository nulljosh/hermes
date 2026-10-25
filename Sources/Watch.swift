import AppIntents
import SwiftUI
import UserNotifications

// Hermes 3.0: the fleet from the menu bar, a notification when an app's review state changes, and Shortcuts.

enum Watch {
    /// "appId|platform" to state, for every version the list knows.
    @MainActor static func snapshot(_ store: Store) -> [String: String] {
        var out: [String: String] = [:]
        for (id, vs) in store.versions { for v in vs { out["\(id)|\(v.platform)"] = v.state } }
        return out
    }

    struct Change: Equatable { let key: String, from: String, to: String }

    /// Only real moves count: a version that appears for the first time is not a change.
    static func changes(from old: [String: String], to new: [String: String]) -> [Change] {
        new.compactMap { k, s in old[k].flatMap { $0 != s ? Change(key: k, from: $0, to: s) : nil } }.sorted { $0.key < $1.key }
    }

    static func words(_ state: String) -> String {
        state.lowercased().replacingOccurrences(of: "_", with: " ")
    }

    /// Called after every load. The first load only records; later loads notify on what moved.
    @MainActor static func check(_ store: Store) {
        let now = snapshot(store), d = UserDefaults.standard
        defer { d.set(now, forKey: "lastStates") }
        guard let old = d.dictionary(forKey: "lastStates") as? [String: String], d.bool(forKey: "notifyReview") else { return }
        for c in changes(from: old, to: now) {
            let parts = c.key.split(separator: "|").map(String.init)
            let id = parts.first ?? "", platform = parts.last ?? ""
            let name = store.apps.first(where: { $0.id == id })?.name ?? "An app"
            let n = UNMutableNotificationContent()
            n.title = "\(name) on \(Theme.platform(platform))"
            n.body = "\(words(c.from).capitalized) to \(words(c.to))."
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: c.key + c.to, content: n, trigger: nil))
        }
    }

    /// Reload every 15 minutes while Hermes runs, so the menu bar and notifications stay current without a click.
    /// ponytail: a plain timer loop; App Store Connect webhooks replace it when Hermes has a server to receive them.
    static func poll(_ store: Store) async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(900))
            await store.load()
        }
    }
}

struct MenuBarView: View {
    let store: Store
    @Environment(\.openWindow) private var openWindow

    /// Rejected first, then in review, then everything else that is not live yet. Live apps stay out of the way.
    var rows: [(ASCApp, PlatformVersion)] {
        func rank(_ s: String) -> Int { s.contains("REJECT") || s == "INVALID_BINARY" ? 0 : s.contains("REVIEW") ? 1 : 2 }
        return store.apps.flatMap { a in (store.versions[a.id] ?? []).map { (a, $0) } }
            .filter { !$0.1.state.hasPrefix("READY_FOR") && $0.1.state != "ACCEPTED" }
            .sorted { (rank($0.1.state), $0.0.name) < (rank($1.1.state), $1.0.name) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(rows.isEmpty ? "Everything is live." : "\(rows.count) not live yet").font(Theme.font(13, .semibold))
            ForEach(rows, id: \.1.id.hashValue) { app, v in
                HStack(spacing: 8) {
                    Circle().fill(Theme.stateColor(v.state)).frame(width: 7, height: 7)
                    Text(app.name).font(Theme.font(12, .medium))
                    Spacer()
                    Text("\(v.version) \(Theme.platform(v.platform)), \(Watch.words(v.state))").font(Theme.font(11)).foregroundStyle(Theme.muted)
                }
            }
            Divider()
            HStack {
                Button("Open Hermes") { openWindow(id: "main"); NSApp.activate() }
                Button("Refresh") { Task { await store.load() } }.disabled(store.loading)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
        }
        .padding(12).frame(width: 340)
    }
}

// Shortcuts: the same fleet read, as actions.

struct FleetStatusIntent: AppIntent {
    static let title: LocalizedStringResource = "Get App Store Status"
    static let description = IntentDescription("Lists every app that is not live yet, with its version and review state.")

    @MainActor func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let s = Store.shared
        if s.apps.isEmpty { await s.load() }
        let lines = s.apps.flatMap { a in (s.versions[a.id] ?? []).filter { !$0.state.hasPrefix("READY_FOR") }
            .map { "\(a.name) \($0.version) \(Theme.platform($0.platform)): \(Watch.words($0.state))" } }
        return .result(value: lines.isEmpty ? "Everything is live." : lines.joined(separator: "\n"))
    }
}

struct AppStatusIntent: AppIntent {
    static let title: LocalizedStringResource = "Get One App's Status"
    @Parameter(title: "App name") var name: String

    @MainActor func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let s = Store.shared
        if s.apps.isEmpty { await s.load() }
        guard let a = s.apps.first(where: { $0.name.localizedCaseInsensitiveContains(name) }) else { return .result(value: "No app named \(name).") }
        let vs = (s.versions[a.id] ?? []).map { "\($0.version) on \(Theme.platform($0.platform)): \(Watch.words($0.state))" }
        return .result(value: "\(a.name)\n" + vs.joined(separator: "\n"))
    }
}

struct HermesShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: FleetStatusIntent(), phrases: ["App Store status in \(.applicationName)", "What is in review in \(.applicationName)"],
                    shortTitle: "App Store Status", systemImageName: "checklist")
    }
}
