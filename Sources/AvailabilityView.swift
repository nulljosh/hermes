import SwiftUI

// Where the app is on sale: count, per-country switches, available everywhere, remove from sale.
struct Territory: Decodable, Identifiable {
    struct Attributes: Decodable { let available: Bool?; let releaseDate: String? }
    struct Relationships: Decodable { struct T: Decodable { struct D: Decodable { let id: String }; let data: D? }; let territory: T? }
    let id: String
    let attributes: Attributes?
    let relationships: Relationships?
    var code: String { relationships?.territory?.data?.id ?? id }
    var available: Bool { attributes?.available ?? false }
}

struct AvailabilityView: View {
    let app: ASCApp
    @State private var territories: [Territory]?
    @State private var query = ""
    @State private var error: String?
    @State private var pending: PendingCommand?

    var shown: [Territory] { (territories ?? []).filter { query.isEmpty || $0.code.localizedCaseInsensitiveContains(query) }.sorted { $0.code < $1.code } }

    var body: some View {
        Form {
            Section("On Sale") {
                if let error { Text(error).foregroundStyle(Theme.bad).textSelection(.enabled) }
                else if let territories {
                    LabeledContent("Countries", value: "\(territories.filter(\.available).count) of \(territories.count)")
                    HStack {
                        Button("Available Everywhere") {
                            pending = PendingCommand(title: "Available Everywhere", args: ["pricing", "availability", "edit", "--app", app.id, "--all-territories", "--available", "true"])
                        }
                        Spacer()
                        Button("Remove from Sale", role: .destructive) {
                            pending = PendingCommand(title: "Remove from Sale", args: ["pricing", "availability", "remove-from-sale", "--app", app.id, "--all-platforms", "--confirm"])
                        }
                    }
                } else { ProgressView() }
            }
            Section("By Country") {
                TextField("Search codes, like USA or FRA", text: $query)
                ForEach(shown) { t in
                    Toggle(isOn: Binding(get: { t.available }, set: { on in
                        pending = PendingCommand(title: on ? "Sell in \(t.code)" : "Stop selling in \(t.code)",
                                                 args: ["pricing", "availability", "edit", "--app", app.id, "--territory", t.code, "--available", on ? "true" : "false"])
                    })) {
                        Text(t.code).font(Theme.font(13, .medium))
                        if let d = t.attributes?.releaseDate { Text("since \(d)").font(Theme.font(11)).foregroundStyle(Theme.muted) }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .commands($pending) { await load() }
        .task { await load() }
    }

    func load() async {
        error = nil
        struct R: Decodable { let data: [Territory]? }
        do {
            territories = try JSONDecoder().decode(R.self, from: await ASC.run(["pricing", "availability", "territory-availabilities",
                                                                               "--availability", app.id, "--limit", "200", "--paginate"])).data ?? []
        } catch { self.error = error.localizedDescription }
    }
}
