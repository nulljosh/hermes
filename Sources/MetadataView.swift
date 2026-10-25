import AppKit
import SwiftUI

// Store listing text per version and language: App Info (name, subtitle, privacy URL) and the version's own fields.
struct MetadataView: View {
    let app: ASCApp
    @State private var versionID = ""
    @State private var locs: [Item] = []
    @State private var infoLocs: [Item] = []
    @State private var locale = ""
    @State private var error: String?
    @State private var pending: PendingCommand?
    @State private var adding = false
    @State private var note: String?
    @State private var reload = 0

    var loc: Item? { locs.first { $0.text("locale") == locale } }
    var infoLoc: Item? { infoLocs.first { $0.text("locale") == locale } }

    var body: some View {
        VStack(spacing: 0) {
            VersionLocaleBar(app: app, versionID: $versionID, locs: $locs, locale: $locale, error: $error, reload: reload) {
                Button("Add Language", systemImage: "plus") { adding = true }
                    .labelStyle(.iconOnly).help("Add Language")
                Button("Export", systemImage: "square.and.arrow.down") { export() }
                    .labelStyle(.iconOnly).help("Export")
                Button("Import", systemImage: "square.and.arrow.up") { Task { await importStrings() } }
                    .labelStyle(.iconOnly).help("Import")
            }
            Divider().overlay(Theme.line)
            if let error {
                Text(error).foregroundStyle(Theme.bad).padding().textSelection(.enabled)
                Spacer()
            } else if let loc {
                LocaleForm(versionLoc: loc, infoLoc: infoLoc, pending: $pending).id(loc.id + (infoLoc?.id ?? ""))
            } else {
                ProgressView().frame(maxHeight: .infinity)
            }
        }
        .commands($pending) { reload += 1 }
        .sheet(isPresented: $adding) { AddLanguage(versionID: versionID) { adding = false; reload += 1 }.font(Theme.font(13)) }
        .alert("Import check", isPresented: Binding(get: { note != nil }, set: { if !$0 { note = nil } })) { Button("OK") {} } message: { Text(note ?? "") }
        .task { await loadInfo() }
    }

    func loadInfo() async {
        do {
            let infos = try await ASC.items(["apps", "info", "list", "--app", app.id])
            // the editable app info is the one not yet live; fall back to the live one
            let info = infos.first { $0.text("state") != "READY_FOR_DISTRIBUTION" } ?? infos.first
            if let info {
                infoLocs = try await ASC.items(["localizations", "list", "--app", app.id, "--type", "app-info", "--app-info", info.id, "--paginate"])
            }
        } catch { self.error = error.localizedDescription }
    }

    func export() {
        guard let dir = pickFolder("Export Here") else { return }
        Task {
            do {
                _ = try await ASC.run(["localizations", "download", "--version", versionID, "--path", dir.path])
                NSWorkspace.shared.open(dir)
            } catch { self.error = error.localizedDescription }
        }
    }

    // Validate with --dry-run first, then ask before the real upload.
    func importStrings() async {
        guard let dir = pickFolder("Import") else { return }
        do {
            _ = try await ASC.run(["localizations", "upload", "--version", versionID, "--path", dir.path, "--dry-run"])
            pending = PendingCommand(title: "Upload Localizations", args: ["localizations", "upload", "--version", versionID, "--path", dir.path])
        } catch {
            note = error.localizedDescription
        }
    }
}

struct LocaleForm: View {
    let versionLoc: Item
    let infoLoc: Item?
    @Binding var pending: PendingCommand?

    @State private var name = ""
    @State private var subtitle = ""
    @State private var privacy = ""
    @State private var description = ""
    @State private var keywords = ""
    @State private var whatsNew = ""
    @State private var promo = ""
    @State private var support = ""
    @State private var marketing = ""

    var body: some View {
        Form {
            if let infoLoc {
                Section("App Info") {
                    counted("Name", $name, 30)
                    counted("Subtitle", $subtitle, 30)
                    TextField("Privacy Policy URL", text: $privacy)
                    Button("Save App Info") {
                        pending = PendingCommand(title: "Save App Info", args: ["localizations", "update", "--type", "app-info", "--id", infoLoc.id]
                            + flags(["--name": name, "--subtitle": subtitle, "--privacy-policy-url": privacy]))
                    }
                }
            }
            Section("Version") {
                counted("Promotional Text", $promo, 170, lines: 2)
                counted("Description", $description, 4000, lines: 8)
                counted("What's New", $whatsNew, 4000, lines: 4)
                counted("Keywords", $keywords, 100)
                TextField("Support URL", text: $support)
                TextField("Marketing URL", text: $marketing)
                Button("Save Version Text") {
                    pending = PendingCommand(title: "Save Version Text", args: ["localizations", "update", "--id", versionLoc.id]
                        + flags(["--promotional-text": promo, "--description": description, "--whats-new": whatsNew,
                                 "--keywords": keywords, "--support-url": support, "--marketing-url": marketing]))
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .onAppear {
            name = infoLoc?.text("name") ?? ""; subtitle = infoLoc?.text("subtitle") ?? ""; privacy = infoLoc?.text("privacyPolicyUrl") ?? ""
            description = versionLoc.text("description") ?? ""; keywords = versionLoc.text("keywords") ?? ""
            whatsNew = versionLoc.text("whatsNew") ?? ""; promo = versionLoc.text("promotionalText") ?? ""
            support = versionLoc.text("supportUrl") ?? ""; marketing = versionLoc.text("marketingUrl") ?? ""
        }
    }

    // Empty fields are left out so a save never clears a field by accident.
    func flags(_ f: [String: String]) -> [String] {
        f.sorted { $0.key < $1.key }.filter { !$0.value.isEmpty }.flatMap { [$0.key, $0.value] }
    }

    func counted(_ title: String, _ text: Binding<String>, _ limit: Int, lines: Int = 1) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text("\(text.wrappedValue.count) / \(limit)")
                    .font(Theme.font(10, .medium))
                    .foregroundStyle(text.wrappedValue.count > limit ? Theme.bad : Theme.muted)
            }
            TextField(title, text: text, axis: .vertical)
                .labelsHidden()
                .lineLimit(lines...max(lines, 20))
                .multilineTextAlignment(.leading)
        }
    }
}

struct AddLanguage: View {
    let versionID: String
    let close: () -> Void
    @State private var locale = ""
    @State private var pending: PendingCommand?

    var body: some View {
        Form {
            TextField("Locale", text: $locale, prompt: Text("ja, fr-FR, zh-Hans"))
            HStack {
                Button("Cancel", action: close)
                Spacer()
                Button("Add") {
                    pending = PendingCommand(title: "Add Language", args: ["localizations", "create", "--version", versionID, "--locale", locale])
                }
                .disabled(locale.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .formStyle(.grouped)
        .frame(width: 360)
        .commands($pending) { close() }
    }
}
