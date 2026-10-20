import SwiftUI

// Builds with their TestFlight actions: add to a group, attach to a version, What to Test notes, expire.
struct BuildsView: View {
    let app: ASCApp
    @State private var builds: [Item]?
    @State private var groups: [Item] = []
    @State private var versions: [Item] = []
    @State private var error: String?
    @State private var pending: PendingCommand?
    @State private var notesFor: Item?

    var body: some View {
        Group {
            if let error { Text(error).foregroundStyle(Theme.bad).padding().textSelection(.enabled) }
            else if let builds {
                if builds.isEmpty { Text("No builds yet.").foregroundStyle(Theme.muted).frame(maxHeight: .infinity) }
                else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) { ForEach(builds) { row($0) } }
                    }
                }
            } else { ProgressView().frame(maxHeight: .infinity) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .commands($pending) { await load() }
        .sheet(item: $notesFor) { b in TestNotes(build: b) { notesFor = nil } }
        .task { await load() }
    }

    func load() async {
        error = nil
        do {
            builds = try await ASC.items(["builds", "list", "--app", app.id, "--limit", "50"])
            groups = (try? await ASC.items(["testflight", "groups", "list", "--app", app.id])) ?? []
            versions = (try? await ASC.items(["versions", "list", "--app", app.id, "--latest"])) ?? []
        } catch { self.error = error.localizedDescription }
    }

    func row(_ b: Item) -> some View {
        let expired = b.bool("expired")
        return HStack(spacing: 8) {
            Circle().fill(expired ? Theme.idle : Theme.stateColor(b.text("processingState") == "VALID" ? "READY_FOR_DISTRIBUTION" : b.text("processingState"))).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(b.text("version") ?? b.id).font(Theme.font(13, .semibold))
                Text([expired ? "EXPIRED" : b.text("processingState"), b.text("uploadedDate").map { String($0.prefix(10)) },
                      b.text("minOsVersion").map { "min OS " + $0 }].compactMap { $0 }.joined(separator: " · "))
                    .font(Theme.font(11)).foregroundStyle(Theme.muted)
            }
            Spacer()
            Menu {
                Menu("Add to Group") {
                    ForEach(groups) { g in
                        Button(g.text("name") ?? g.id) {
                            pending = PendingCommand(title: "Add to \(g.text("name") ?? "group")", args: ["builds", "add-groups", "--build-id", b.id, "--group", g.id])
                        }
                    }
                    if groups.isEmpty { Text("No groups yet") }
                }
                Menu("Attach to Version") {
                    ForEach(versions) { v in
                        Button("\(v.text("versionString") ?? "") \(Theme.platform(v.text("platform") ?? ""))") {
                            pending = PendingCommand(title: "Attach Build", args: ["versions", "attach-build", "--version-id", v.id, "--build-id", b.id])
                        }
                    }
                }
                Button("What to Test...") { notesFor = b }
                Divider()
                Button("Expire", role: .destructive) {
                    pending = PendingCommand(title: "Expire Build", args: ["builds", "expire", "--build-id", b.id, "--confirm"])
                }
                .disabled(expired)
            } label: { Image(systemName: "ellipsis.circle") }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
        }
        .padding(.horizontal, 8).padding(.vertical, 10)
        .contentShape(Rectangle())
        .hoverable()
    }
}

extension Item: Hashable {
    static func == (a: Item, b: Item) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}

struct TestNotes: View {
    let build: Item
    let close: () -> Void
    @State private var locale = "en-US"
    @State private var text = ""
    @State private var pending: PendingCommand?

    var body: some View {
        Form {
            Text("Build \(build.text("version") ?? "")").font(Theme.font(13, .semibold))
            TextField("Language", text: $locale)
            TextField("What to Test", text: $text, axis: .vertical).lineLimit(4...10)
            Text("\(text.count) / 4000").font(.caption).foregroundStyle(text.count > 4000 ? Theme.bad : .secondary)
            HStack {
                Button("Cancel", action: close)
                Spacer()
                Button("Save") {
                    pending = PendingCommand(title: "Save What to Test", args: ["builds", "test-notes", "update", "--build-id", build.id, "--locale", locale, "--whats-new", text])
                }
                .disabled(text.isEmpty).keyboardShortcut(.defaultAction)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .commands($pending) { close() }
    }
}
