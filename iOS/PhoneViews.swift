import SwiftUI
import UniformTypeIdentifiers

// MARK: - Key

struct KeyView: View {
    var onSave: (ASCKey) -> Void
    @State private var keyID = ""
    @State private var issuerID = ""
    @State private var pem = ""
    @State private var importing = false
    @State private var checking = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Key ID", text: $keyID).textInputAutocapitalization(.characters).autocorrectionDisabled()
                    TextField("Issuer ID", text: $issuerID).textInputAutocapitalization(.never).autocorrectionDisabled()
                } footer: { Text("App Store Connect, Users and Access, Integrations.") }
                Section {
                    Button(pem.isEmpty ? "Import .p8 file" : "Key file loaded") { importing = true }
                } footer: { Text("Your key stays in your Keychain. Hermes has no server.") }
                if let error { Section { Text(error).foregroundStyle(Theme.bad) } }
                Section {
                    Button { Task { await check() } } label: {
                        HStack { Text("Connect"); Spacer(); if checking { ProgressView() } }
                    }
                    .disabled(keyID.isEmpty || issuerID.isEmpty || pem.isEmpty || checking)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .navigationTitle("Hermes")
            .fileImporter(isPresented: $importing, allowedContentTypes: [.data, .plainText]) { result in
                guard let url = try? result.get(), url.startAccessingSecurityScopedResource() else { return }
                defer { url.stopAccessingSecurityScopedResource() }
                pem = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
                if keyID.isEmpty, let m = url.lastPathComponent.firstMatch(of: /AuthKey_([A-Z0-9]+)\.p8/) { keyID = String(m.1) }
            }
        }
    }

    private func check() async {
        checking = true; defer { checking = false }
        let key = ASCKey(keyID: keyID.trimmingCharacters(in: .whitespaces), issuerID: issuerID.trimmingCharacters(in: .whitespaces), pem: pem)
        do { _ = try await ASCClient(key: key).apps(); onSave(key) }
        catch { self.error = error.localizedDescription }
    }
}

// MARK: - Apps

struct PhoneApp: Identifiable, Hashable {
    let id: String, name: String, bundleId: String
    var versions: [Version] = []
    var icon: URL?
    struct Version: Hashable { let platform: String, version: String, state: String }
}

/// The whole account, loaded once and shared by every tab.
@Observable final class Fleet {
    let client: ASCClient
    var apps: [PhoneApp] = []
    var loading = false
    var error: String?
    init(client: ASCClient) { self.client = client }

    func load() async {
        loading = true; defer { loading = false }
        do {
            var list = try await client.apps().map { PhoneApp(id: $0.id, name: $0.attributes.name, bundleId: $0.attributes.bundleId) }
            if apps.isEmpty { apps = list }
            // Versions and icons per app, five apps at a time so Apple's rate limit never trips.
            for chunk in stride(from: 0, to: list.count, by: 5).map({ Array(list.indices[$0..<min($0 + 5, list.count)]) }) {
                await withTaskGroup(of: (Int, [PhoneApp.Version], URL?).self) { group in
                    for i in chunk {
                        let id = list[i].id, client = client
                        group.addTask {
                            async let icon = try? client.icon(id)
                            let v = (try? await client.versions(id, limit: 10)) ?? []
                            return (i, latestPerPlatform(v).map { .init(platform: $0.attributes.platform ?? "", version: $0.attributes.versionString ?? "", state: $0.attributes.appVersionState ?? $0.attributes.appStoreState ?? "") }, await icon ?? nil)
                        }
                    }
                    for await (i, v, icon) in group { list[i].versions = v; list[i].icon = icon }
                }
            }
            apps = list
            error = nil
        } catch { self.error = error.localizedDescription }
    }
}

struct AppsView: View {
    let fleet: Fleet
    @State private var query = ""
    @State private var path: [PhoneApp] = []

    var shown: [PhoneApp] { query.isEmpty ? fleet.apps : fleet.apps.filter { $0.name.localizedCaseInsensitiveContains(query) || $0.bundleId.localizedCaseInsensitiveContains(query) } }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if let error = fleet.error { Text(error).foregroundStyle(Theme.bad) }
                ForEach(shown) { app in
                    NavigationLink(value: app) { AppRow(app: app) }.listRowBackground(Theme.surface)
                }
            }
            .overlay { if fleet.loading && fleet.apps.isEmpty { ProgressView() } }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .navigationTitle("Apps")
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search Apps")
            .refreshable { await fleet.load() }
            .navigationDestination(for: PhoneApp.self) { AppDetail(client: fleet.client, app: $0) }
            .onChange(of: fleet.apps) {
                #if DEBUG
                // QA: HERMES_OPEN_APP=<name> opens that app on launch.
                if path.isEmpty, let name = ProcessInfo.processInfo.environment["HERMES_OPEN_APP"], let app = fleet.apps.first(where: { $0.name == name }), app.icon != nil { path = [app] }
                #endif
            }
        }
    }
}

/// Every app sorted by where it stands, the ones that need you first.
struct StatusView: View {
    let fleet: Fleet
    enum Group: String, CaseIterable { case rejected = "Rejected", review = "In review", preparing = "Preparing", sale = "On sale" }

    static func group(_ app: PhoneApp) -> Group {
        let states = app.versions.map(\.state)
        if states.contains(where: { Theme.stateColor($0) == Theme.bad }) { return .rejected }
        if states.contains(where: { Theme.stateColor($0) == Theme.pending }) { return .review }
        if states.contains(where: { Theme.stateColor($0) == Theme.idle }) || states.isEmpty { return .preparing }
        return .sale
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(Group.allCases, id: \.self) { g in
                    let apps = fleet.apps.filter { Self.group($0) == g }
                    if !apps.isEmpty {
                        Section {
                            ForEach(apps) { app in NavigationLink(value: app) { AppRow(app: app) }.listRowBackground(Theme.surface) }
                        } header: {
                            Text("\(g.rawValue.uppercased())  \(apps.count)").font(Theme.display(17, medium: true)).tracking(1.2).foregroundStyle(Theme.muted)
                        }
                    }
                }
            }
            .overlay { if fleet.loading && fleet.apps.allSatisfy({ $0.versions.isEmpty }) { ProgressView() } }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .navigationTitle("Status")
            .refreshable { await fleet.load() }
            .navigationDestination(for: PhoneApp.self) { AppDetail(client: fleet.client, app: $0) }
        }
    }
}

struct SettingsView: View {
    let fleet: Fleet
    var onDisconnect: () -> Void
    @AppStorage("onboarded") private var onboarded = true
    @AppStorage("signature") private var signature = ""
    @State private var confirm = false

    func masked(_ s: String) -> String { String(repeating: "•", count: max(0, min(s.count, 12) - 4)) + s.suffix(4) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Key ID", value: masked(fleet.client.key.keyID))
                    LabeledContent("Issuer", value: masked(fleet.client.key.issuerID))
                    LabeledContent("Apps", value: "\(fleet.apps.count)")
                    Button("Disconnect key", role: .destructive) { confirm = true }
                } header: { Text("App Store Connect") } footer: { Text("Your key lives in your Keychain and syncs only through iCloud Keychain.") }
                Section {
                    LabeledContent("Changes", value: "Ask first")
                    TextField("Reply signature", text: $signature)
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                    Button("Show the intro again") { onboarded = false }
                } header: { Text("Hermes") }
                Section {
                    Link("Docs", destination: URL(string: "https://hermes.jaybulb.com/docs")!)
                    Link("Send feedback", destination: URL(string: "mailto:trommatic@icloud.com?subject=Hermes%20iOS")!)
                    Link("Source on GitHub", destination: URL(string: "https://github.com/nulljosh/hermes")!)
                    Link("Privacy", destination: URL(string: "https://hermes.jaybulb.com/privacy")!)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .navigationTitle("Settings")
            .confirmationDialog("Disconnect this key?", isPresented: $confirm, titleVisibility: .visible) {
                Button("Disconnect", role: .destructive, action: onDisconnect)
            } message: { Text("It is removed from this device's Keychain. Your account is not touched.") }
        }
    }
}

struct Tile: View {
    let name: String
    var icon: URL?
    var size: CGFloat = 44
    var fill = Theme.bg
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
        AsyncImage(url: icon) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            Text(String(name.prefix(1))).font(Theme.font(size * 0.45, .semibold)).foregroundStyle(Theme.accent)
                .frame(maxWidth: .infinity, maxHeight: .infinity).background(fill)
        }
        .frame(width: size, height: size)
        .clipShape(shape)
    }
}

struct StateLine: View {
    let state: String, text: String
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(Theme.stateColor(state)).frame(width: 7, height: 7)
            Text(text).font(Theme.font(12, .medium)).foregroundStyle(Theme.muted)
        }
    }
}

struct AppRow: View {
    let app: PhoneApp
    var body: some View {
        HStack(spacing: 12) {
            Tile(name: app.name, icon: app.icon)
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name).font(Theme.font(16, .semibold)).foregroundStyle(Theme.text)
                ForEach(app.versions, id: \.platform) { StateLine(state: $0.state, text: "\($0.version) on \(Theme.platform($0.platform))") }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Writes, each one asks first

struct ReplySheet: View {
    let client: ASCClient
    let review: Doc<ReviewAttrs>.Item
    @Environment(\.dismiss) private var dismiss
    @AppStorage("signature") private var signature = ""
    @State private var text = ""
    @State private var confirm = false
    @State private var sending = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(review.attributes.title ?? "").font(Theme.font(15, .semibold))
                    Text(review.attributes.body ?? "").font(Theme.font(14)).foregroundStyle(Theme.muted)
                }
                Section {
                    TextEditor(text: $text).frame(minHeight: 140)
                } footer: { Text("Your reply shows publicly on the App Store.") }
                if let error { Section { Text(error).foregroundStyle(Theme.bad) } }
            }
            .navigationTitle("Reply")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { if text.isEmpty && !signature.isEmpty { text = "\n\n" + signature } }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") { confirm = true }.disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || sending)
                }
            }
            .confirmationDialog("Publish this reply on the App Store?", isPresented: $confirm, titleVisibility: .visible) {
                Button("Publish") {
                    Task {
                        sending = true; defer { sending = false }
                        do { try await client.reply(to: review.id, text); dismiss() } catch { self.error = error.localizedDescription }
                    }
                }
            }
        }
    }
}

// MARK: - One app

struct AppDetail: View {
    let client: ASCClient
    let app: PhoneApp
    enum Tab: String, CaseIterable { case versions = "Versions", builds = "Builds", reviews = "Reviews" }
    @State private var tab = Tab(rawValue: ProcessInfo.processInfo.environment["HERMES_TAB"] ?? "") ?? .versions
    @State private var versions: [Doc<VersionAttrs>.Item] = []
    @State private var builds: [Doc<BuildAttrs>.Item] = []
    @State private var reviews: [Doc<ReviewAttrs>.Item] = []
    @State private var icon: URL?
    @State private var replying: Doc<ReviewAttrs>.Item?
    @State private var error: String?

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    Tile(name: app.name, icon: icon ?? app.icon, size: 56, fill: Theme.surface)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(app.name).font(Theme.font(20, .semibold))
                        Text(app.bundleId).font(Theme.font(13)).foregroundStyle(Theme.muted)
                    }
                }
                Picker("", selection: $tab) { ForEach(Tab.allCases, id: \.self) { Text($0.rawValue) } }.pickerStyle(.segmented)
            }
            .listRowBackground(Color.clear)
            if let error { Text(error).foregroundStyle(Theme.bad) }
            Section {
                switch tab {
                case .versions:
                    ForEach(versions) { v in
                        let a = v.attributes
                        VStack(alignment: .leading, spacing: 2) {
                            Text(a.versionString ?? "").font(Theme.font(16, .semibold))
                            StateLine(state: a.appVersionState ?? a.appStoreState ?? "", text: "\(Theme.platform(a.platform ?? "")) · \(a.appVersionState ?? a.appStoreState ?? "") · \(String((a.createdDate ?? "").prefix(10)))")
                        }
                    }
                case .builds:
                    ForEach(builds) { b in
                        let a = b.attributes
                        VStack(alignment: .leading, spacing: 2) {
                            Text(a.version ?? "").font(Theme.font(16, .semibold))
                            StateLine(state: a.processingState == "VALID" ? "READY_FOR_SALE" : (a.processingState ?? ""), text: "\(a.processingState ?? "") · \(String((a.uploadedDate ?? "").prefix(10))) · min OS \(a.minOsVersion ?? "")")
                        }
                    }
                case .reviews:
                    if reviews.isEmpty { Text("No reviews here yet.").foregroundStyle(Theme.muted) }
                    ForEach(reviews) { r in
                        let a = r.attributes
                        Button { replying = r } label: { VStack(alignment: .leading, spacing: 4) {
                            Text(String(repeating: "★", count: a.rating ?? 0) + " " + (a.title ?? "")).font(Theme.font(15, .semibold))
                            Text(a.body ?? "").font(Theme.font(14)).foregroundStyle(Theme.muted)
                            Text("\(a.reviewerNickname ?? "") · \(a.territory ?? "") · \(String((a.createdDate ?? "").prefix(10)))").font(Theme.font(12)).foregroundStyle(Theme.muted)
                        } }.foregroundStyle(Theme.text)
                    }
                }
            }
            .listRowBackground(Theme.surface)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.bg)
        .navigationTitle(app.name)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { await load() }
        .sheet(item: $replying) { r in ReplySheet(client: client, review: r) }
    }

    private func load() async {
        do {
            if app.icon == nil { icon = try? await client.icon(app.id) }
            async let v = client.versions(app.id), b = client.builds(app.id), r = client.reviews(app.id)
            (versions, builds, reviews) = try await (v, b, r)
            error = nil
        } catch { self.error = error.localizedDescription }
    }
}
