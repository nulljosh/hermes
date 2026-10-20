import SwiftUI

// In-app purchases with price and proceeds; open one to rename it, edit its text per language, add it to a submission, or delete it.
struct IAPSummary: Decodable, Identifiable {
    struct Money: Decodable { let amount: String?; let currency: String? }
    let id: String
    let name: String?
    let productId: String?
    let type: String?
    let currentPrice: Money?
    let estimatedProceeds: Money?

    static func price(_ m: Money?) -> String? {
        guard let a = m?.amount, let v = Double(a) else { return nil }
        return String(format: "%.2f %@", v, m?.currency ?? "")
    }
}

struct PurchasesView: View {
    let app: ASCApp
    @State private var iaps: [IAPSummary]?
    @State private var error: String?
    @State private var open: IAPSummary?
    @State private var creating = false
    @State private var pending: PendingCommand?

    var body: some View {
        Group {
            if let open {
                IAPDetail(app: app, iap: open) { self.open = nil; Task { await load() } }
            } else if let error {
                Text(error).foregroundStyle(Theme.bad).padding().textSelection(.enabled)
            } else if let iaps {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        HStack { Spacer(); Button("New Purchase", systemImage: "plus") { creating = true } }
                            .padding(.horizontal, 16).padding(.vertical, 8)
                        if iaps.isEmpty { Text("No in-app purchases yet.").foregroundStyle(Theme.muted).padding(16) }
                        ForEach(iaps) { i in Button { open = i } label: { row(i) }.buttonStyle(.plain) }
                    }
                }
            } else { ProgressView().frame(maxHeight: .infinity) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .commands($pending) { await load() }
        .sheet(isPresented: $creating) { NewIAP(app: app) { cmd in creating = false; if let cmd { pending = cmd } } }
        .task { await load() }
    }

    func load() async {
        error = nil
        struct R: Decodable { let iaps: [IAPSummary]? }
        do { iaps = try JSONDecoder().decode(R.self, from: await ASC.run(["iap", "pricing", "summary", "--app", app.id])).iaps ?? [] }
        catch { self.error = error.localizedDescription }
    }

    func row(_ i: IAPSummary) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "bag").foregroundStyle(Theme.accent).frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(i.name ?? i.id).font(Theme.font(13, .semibold))
                Text([i.productId, i.type?.replacingOccurrences(of: "_", with: " ").lowercased()].compactMap { $0 }.joined(separator: " · "))
                    .font(Theme.font(11)).foregroundStyle(Theme.muted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(IAPSummary.price(i.currentPrice) ?? "No price").font(Theme.font(13, .semibold))
                if let p = IAPSummary.price(i.estimatedProceeds) { Text("you get \(p)").font(Theme.font(11)).foregroundStyle(Theme.muted) }
            }
            Image(systemName: "chevron.right").foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, 8).padding(.vertical, 10)
        .contentShape(Rectangle())
        .hoverable()
    }
}

struct IAPDetail: View {
    let app: ASCApp
    let iap: IAPSummary
    let back: () -> Void
    @State private var refName = ""
    @State private var versions: [Item] = []
    @State private var locs: [Item] = []
    @State private var drafts: [Submission] = []
    @State private var pending: PendingCommand?
    @State private var newLocale = ""
    @State private var newPrice = "0.99"

    var version: Item? { versions.first }

    var body: some View {
        Form {
            Section {
                HStack {
                    Button(action: back) { Label("Purchases", systemImage: "chevron.left") }.buttonStyle(.plain).foregroundStyle(Theme.accent)
                    Spacer()
                    Text(IAPSummary.price(iap.currentPrice) ?? "").foregroundStyle(Theme.muted)
                }
            }
            Section("Purchase") {
                LabeledContent("Product ID", value: iap.productId ?? "")
                Picker("Price (US)", selection: $newPrice) { ForEach(["0.99", "1.99", "2.99", "4.99", "9.99"], id: \.self) { Text($0).tag($0) } }
                Button("Set Price") {
                    pending = PendingCommand(title: "Set Purchase Price", args: ["iap", "pricing", "schedules", "create", "--iap-id", iap.id, "--base-territory", "USA", "--price", newPrice])
                }
                TextField("Reference name", text: $refName)
                Button("Save Name") { pending = PendingCommand(title: "Save Name", args: ["iap", "update", "--id", iap.id, "--ref-name", refName]) }
            }
            if let version {
                Section("Version \(version.text("version") ?? "") · \(version.text("state") ?? "")") {
                    ForEach(locs) { l in IAPText(loc: l, pending: $pending) }
                    HStack {
                        TextField("Add a language", text: $newLocale, prompt: Text("fr-FR"))
                        Button("Add") {
                            pending = PendingCommand(title: "Add Language", args: ["iap", "versions", "localizations", "create", "--version-id", version.id, "--locale", newLocale, "--name", iap.name ?? refName])
                        }
                        .disabled(newLocale.isEmpty)
                    }
                    Menu("Add to Submission") {
                        ForEach(drafts) { d in
                            Button("\(d.versionString ?? "Draft") \(Theme.platform(d.platform ?? ""))") {
                                pending = PendingCommand(title: "Add to Submission", args: ["iap", "versions", "submit", "--version-id", version.id, "--submission", d.id, "--confirm"])
                            }
                        }
                        if drafts.isEmpty { Text("No draft submissions. Make one in Submissions.") }
                    }
                }
            } else {
                Section("Version") {
                    Button("Create Version") { pending = PendingCommand(title: "Create Version", args: ["iap", "versions", "create", "--iap-id", iap.id]) }
                }
            }
            Section {
                Button("Delete Purchase", role: .destructive) { pending = PendingCommand(title: "Delete Purchase", args: ["iap", "delete", "--id", iap.id, "--confirm"]) }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .commands($pending) { newLocale = ""; await load() }
        .task { refName = iap.name ?? ""; await load() }
    }

    func load() async {
        versions = (try? await ASC.items(["iap", "versions", "list", "--iap-id", iap.id])) ?? []
        if let v = version { locs = (try? await ASC.items(["iap", "versions", "localizations", "list", "--version-id", v.id])) ?? [] }
        let all = (try? JSONDecoder().decode([Submission].self, from: await ASC.run(["review", "history", "--app", app.id, "--limit", "20"]))) ?? []
        drafts = all.filter { $0.state == "READY_FOR_REVIEW" }
    }
}

struct IAPText: View {
    let loc: Item
    @Binding var pending: PendingCommand?
    @State private var name = ""
    @State private var description = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Locale.current.localizedString(forIdentifier: loc.text("locale") ?? "") ?? loc.text("locale") ?? "").font(Theme.font(12, .semibold))
            HStack { TextField("Name", text: $name); Text("\(name.count) / 35").font(Theme.font(10)).foregroundStyle(name.count > 35 ? Theme.bad : Theme.muted) }
            HStack { TextField("Description", text: $description); Text("\(description.count) / 55").font(Theme.font(10)).foregroundStyle(description.count > 55 ? Theme.bad : Theme.muted) }
            Button("Save") {
                pending = PendingCommand(title: "Save Purchase Text", args: ["iap", "versions", "localizations", "update", "--localization-id", loc.id, "--name", name, "--description", description])
            }
        }
        .onAppear { name = loc.text("name") ?? ""; description = loc.text("description") ?? "" }
    }
}

struct NewIAP: View {
    let app: ASCApp
    let done: (PendingCommand?) -> Void
    @State private var name = ""
    @State private var productId = ""
    @State private var type = "NON_CONSUMABLE"

    var body: some View {
        Form {
            TextField("Reference name", text: $name)
            TextField("Product ID", text: $productId, prompt: Text("\(app.bundleId).unlock"))
            Picker("Type", selection: $type) {
                Text("Non-consumable").tag("NON_CONSUMABLE"); Text("Consumable").tag("CONSUMABLE"); Text("Non-renewing subscription").tag("NON_RENEWING_SUBSCRIPTION")
            }
            HStack {
                Button("Cancel") { done(nil) }
                Spacer()
                Button("Create") {
                    done(PendingCommand(title: "Create Purchase", args: ["iap", "create", "--app", app.id, "--type", type, "--ref-name", name, "--product-id", productId]))
                }
                .disabled(name.isEmpty || productId.isEmpty).keyboardShortcut(.defaultAction)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
    }
}
