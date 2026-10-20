import SwiftUI

struct VersionsView: View {
    let app: ASCApp
    @State private var items: [Item]?
    @State private var error: String?
    @State private var open: Item?
    @State private var creating = false

    var body: some View {
        Group {
            if let open {
                VersionDetail(app: app, version: open) { self.open = nil; Task { await load() } }
            } else if let error {
                Text(error).foregroundStyle(Theme.bad).padding().textSelection(.enabled)
            } else if let items {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Spacer()
                            Button("New Version", systemImage: "plus") { creating = true }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        ForEach(items) { v in
                            Button { open = v } label: { row(v) }.buttonStyle(.plain)
                        }
                    }
                }
            } else {
                ProgressView().frame(maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $creating) { NewVersion(app: app, latest: items?.first) { creating = false; Task { await load() } } }
        .task { await load() }
    }

    func load() async {
        error = nil
        do { items = try await ASC.items(["versions", "list", "--app", app.id, "--paginate"]) } catch { self.error = error.localizedDescription }
        // QA launch argument: -openVersion first opens the newest version.
        if open == nil, UserDefaults.standard.string(forKey: "openVersion") == "first" { open = items?.first }
    }

    func row(_ v: Item) -> some View {
        HStack(spacing: 8) {
            Circle().fill(Theme.stateColor(v.text("appVersionState"))).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(v.text("versionString") ?? v.id).font(Theme.font(13, .semibold))
                Text([v.text("platform").map(Theme.platform), v.text("appVersionState"), v.text("createdDate").map { String($0.prefix(10)) }]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(Theme.font(11)).foregroundStyle(Theme.muted)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, 8).padding(.vertical, 10)
        .contentShape(Rectangle())
        .hoverable()
    }
}

struct VersionDetail: View {
    let app: ASCApp
    let version: Item
    let back: () -> Void

    @State private var versionString = ""
    @State private var copyright = ""
    @State private var releaseType = "AFTER_APPROVAL"
    @State private var review: Item?
    @State private var first = ""
    @State private var last = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var notes = ""
    @State private var demoName = ""
    @State private var demoRequired = false
    @State private var attachments: [Item] = []
    @State private var attaching = false
    @State private var pending: PendingCommand?

    var state: String { version.text("appVersionState") ?? version.text("appStoreState") ?? "" }
    var editable: Bool { ["PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED", "INVALID_BINARY"].contains(state) }

    var body: some View {
        Form {
            Section {
                HStack {
                    Button(action: back) { Label("Versions", systemImage: "chevron.left") }.buttonStyle(.plain).foregroundStyle(Theme.accent)
                    Spacer()
                    Circle().fill(Theme.stateColor(state)).frame(width: 8, height: 8)
                    Text(state).foregroundStyle(Theme.muted)
                }
            }
            Section("Version") {
                TextField("Version", text: $versionString)
                Picker("Release", selection: $releaseType) {
                    Text("Automatically after approval").tag("AFTER_APPROVAL")
                    Text("Manually").tag("MANUAL")
                    Text("Scheduled").tag("SCHEDULED")
                }
                TextField("Copyright", text: $copyright)
                Button("Save Version") {
                    pending = PendingCommand(title: "Save Version", args: ["versions", "update", "--version-id", version.id,
                        "--version", versionString, "--release-type", releaseType, "--copyright", copyright])
                }
                .disabled(!editable)
            }
            Section("App Review") {
                TextField("First name", text: $first)
                TextField("Last name", text: $last)
                TextField("Phone", text: $phone)
                TextField("Email", text: $email)
                Toggle("Sign-in required", isOn: $demoRequired)
                if demoRequired { TextField("Demo account", text: $demoName) }
                TextField("Notes", text: $notes, axis: .vertical).lineLimit(4...12)
                Button("Save Review Info") {
                    guard let id = review?.id else { return }
                    pending = PendingCommand(title: "Save Review Info", args: ["review", "details-update", "--id", id,
                        "--contact-first-name", first, "--contact-last-name", last, "--contact-phone", phone, "--contact-email", email,
                        "--demo-account-required", demoRequired ? "true" : "false", "--notes", notes]
                        + (demoRequired ? ["--demo-account-name", demoName] : []))
                }
                .disabled(review == nil)
                ForEach(attachments) { a in
                    HStack {
                        Image(systemName: "paperclip").foregroundStyle(Theme.muted)
                        Text(a.text("fileName") ?? a.id)
                        Spacer()
                        Button("Remove", role: .destructive) {
                            pending = PendingCommand(title: "Remove Attachment", args: ["review", "attachments-delete", "--id", a.id, "--confirm"])
                        }
                    }
                }
                Button("Attach a File...") { attaching = true }
                    .disabled(review == nil)
                    .fileImporter(isPresented: $attaching, allowedContentTypes: [.item]) { result in
                        guard let id = review?.id, let url = try? result.get() else { return }
                        pending = PendingCommand(title: "Attach File", args: ["review", "attachments-upload", "--review-detail", id, "--file", url.path])
                    }
            }
            Section("Ship") {
                if editable {
                    Button("Submit for Review") {
                        pending = PendingCommand(title: "Submit for Review", args: ["review", "submit", "--version-id", version.id, "--latest", "--confirm"])
                    }
                }
                if state == "PENDING_DEVELOPER_RELEASE" {
                    Button("Release Now") {
                        pending = PendingCommand(title: "Release Now", args: ["versions", "release", "--version-id", version.id, "--confirm"])
                    }
                }
                if state == "PREPARE_FOR_SUBMISSION" {
                    Button("Delete Version", role: .destructive) {
                        pending = PendingCommand(title: "Delete Version", args: ["versions", "delete", "--version-id", version.id, "--confirm"])
                    }
                }
                if !editable && state != "PENDING_DEVELOPER_RELEASE" {
                    Text("Nothing to ship in this state.").foregroundStyle(Theme.muted)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .commands($pending) { await loadReview() }
        .task {
            versionString = version.text("versionString") ?? ""
            copyright = version.text("copyright") ?? ""
            releaseType = version.text("releaseType") ?? "AFTER_APPROVAL"
            await loadReview()
        }
    }

    func loadReview() async {
        guard let r = try? await ASC.one(["review", "details-for-version", "--version-id", version.id]) else { return }
        review = r
        first = r.text("contactFirstName") ?? ""; last = r.text("contactLastName") ?? ""
        phone = r.text("contactPhone") ?? ""; email = r.text("contactEmail") ?? ""
        notes = r.text("notes") ?? ""; demoName = r.text("demoAccountName") ?? ""
        demoRequired = r.bool("demoAccountRequired")
        attachments = (try? await ASC.items(["review", "attachments-list", "--review-detail", r.id])) ?? []
    }
}

struct NewVersion: View {
    let app: ASCApp
    let latest: Item?
    let close: () -> Void
    @State private var version = ""
    @State private var platform = "IOS"
    @State private var copyFrom = true
    @State private var pending: PendingCommand?

    var body: some View {
        Form {
            TextField("Version", text: $version, prompt: Text("2.0.0"))
            Picker("Platform", selection: $platform) {
                ForEach(["IOS", "MAC_OS", "TV_OS", "VISION_OS"], id: \.self) { Text(Theme.platform($0)).tag($0) }
            }
            if let from = latest?.text("versionString") {
                Toggle("Copy metadata from \(from)", isOn: $copyFrom)
            }
            HStack {
                Button("Cancel", action: close)
                Spacer()
                Button("Create") {
                    var args = ["versions", "create", "--app", app.id, "--version", version, "--platform", platform]
                    if copyFrom, let from = latest?.text("versionString") { args += ["--copy-metadata-from", from] }
                    pending = PendingCommand(title: "Create Version", args: args)
                }
                .disabled(version.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .formStyle(.grouped)
        .frame(width: 380)
        .commands($pending) { close() }
    }
}
