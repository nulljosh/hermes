import AppKit
import SwiftUI

// Version and language pickers shared by the Metadata and Media tabs. Bump `reload` to refetch the languages.
struct VersionLocaleBar<Trailing: View>: View {
    let app: ASCApp
    @Binding var versionID: String
    @Binding var locs: [Item]
    @Binding var locale: String
    @Binding var error: String?
    var reload = 0
    @ViewBuilder var trailing: Trailing
    @State private var versions: [Item] = []

    var body: some View {
        HStack(spacing: 12) {
            Picker("Version", selection: $versionID) {
                ForEach(versions) { v in
                    Text("\(v.text("versionString") ?? "") \(Theme.platform(v.text("platform") ?? ""))").tag(v.id)
                }
            }
            .frame(minWidth: 140, maxWidth: 220)
            Picker("Language", selection: $locale) {
                ForEach(locs.compactMap { $0.text("locale") }, id: \.self) { Text(Locale.current.localizedString(forIdentifier: $0) ?? $0).tag($0) }
            }
            .frame(minWidth: 140, maxWidth: 280)
            Spacer(minLength: 8)
            trailing
        }
        .padding(12)
        .task {
            do {
                versions = try await ASC.items(["versions", "list", "--app", app.id, "--latest"])
                versionID = versions.first?.id ?? ""
            } catch { self.error = error.localizedDescription }
        }
        .onChange(of: versionID) { Task { await loadLocales() } }
        .onChange(of: reload) { Task { await loadLocales() } }
    }

    func loadLocales() async {
        guard !versionID.isEmpty else { return }
        do {
            locs = try await ASC.items(["localizations", "list", "--version", versionID, "--paginate"])
            if !locs.contains(where: { $0.text("locale") == locale }) { locale = locs.first?.text("locale") ?? "" }
        } catch { self.error = error.localizedDescription }
    }
}

func pickFolder(_ prompt: String) -> URL? {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.canCreateDirectories = true
    panel.prompt = prompt
    return panel.runModal() == .OK ? panel.url : nil
}
