import SwiftUI
import UniformTypeIdentifiers

// Account switcher for the sidebar footer, and the sheet that adds an App Store Connect API key to asc.
struct AccountMenu: View {
    @AppStorage("profile") private var profile = ""
    @State private var profiles: [ASC.Profile] = []
    @State private var adding = false

    var current: String { profile.isEmpty ? (profiles.first { $0.isDefault == true }?.name ?? "Account") : profile }

    var body: some View {
        Menu {
            ForEach(profiles, id: \.name) { p in
                Button { profile = p.name } label: {
                    if p.name == current { Label(p.name, systemImage: "checkmark") } else { Text(p.name) }
                }
            }
            Divider()
            Button("Add Account...") { adding = true }
        } label: { Text(current).font(Theme.font(11, .medium)) }
        .menuStyle(.borderlessButton).fixedSize()
        .sheet(isPresented: $adding) { AddAccount { adding = false; Task { profiles = await ASC.profiles() } } }
        .task { profiles = await ASC.profiles() }
    }
}

struct AddAccount: View {
    let close: () -> Void
    @State private var name = ""
    @State private var keyID = ""
    @State private var issuerID = ""
    @State private var keyFile: URL?
    @State private var picking = false
    @State private var pending: PendingCommand?

    var body: some View {
        Form {
            Text("Make a key at App Store Connect, Users and Access, Integrations. Hermes hands it to asc; it never stores it itself.")
                .font(.caption).foregroundStyle(.secondary)
            TextField("Name", text: $name, prompt: Text("Work"))
            TextField("Key ID", text: $keyID)
            TextField("Issuer ID", text: $issuerID)
            HStack {
                Text(keyFile?.lastPathComponent ?? "No .p8 file")
                Spacer()
                Button("Choose Key File") { picking = true }
            }
            HStack {
                Button("Cancel", action: close)
                Spacer()
                Button("Add") {
                    guard let keyFile else { return }
                    pending = PendingCommand(title: "Add Account", args: ["auth", "login", "--bypass-keychain", "--network", "--name", name,
                                                                         "--key-id", keyID, "--issuer-id", issuerID, "--private-key", keyFile.path])
                }
                .disabled(name.isEmpty || keyID.isEmpty || issuerID.isEmpty || keyFile == nil)
                .keyboardShortcut(.defaultAction)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fileImporter(isPresented: $picking, allowedContentTypes: [UTType(filenameExtension: "p8") ?? .data]) { keyFile = try? $0.get() }
        .commands($pending) { close() }
    }
}
