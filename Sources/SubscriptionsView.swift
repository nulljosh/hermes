import SwiftUI

// Subscription groups and the subscriptions in them: create, delete. Prices and offers come later.
struct SubscriptionsView: View {
    let app: ASCApp
    @State private var groups: [Item]?
    @State private var subs: [String: [Item]] = [:]
    @State private var error: String?
    @State private var pending: PendingCommand?
    @State private var newGroup = ""
    @State private var addingTo: Item?

    var body: some View {
        Group {
            if let error { Text(error).foregroundStyle(Theme.bad).padding().textSelection(.enabled) }
            else if let groups {
                Form {
                    if groups.isEmpty { Text("No subscription groups yet.").foregroundStyle(Theme.muted) }
                    ForEach(groups) { g in
                        Section(g.text("referenceName") ?? g.id) {
                            ForEach(subs[g.id] ?? []) { s in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(s.text("name") ?? s.id).font(Theme.font(13, .semibold))
                                        Text([s.text("productId"), s.text("subscriptionPeriod")?.replacingOccurrences(of: "_", with: " ").lowercased(), s.text("state")]
                                            .compactMap { $0 }.joined(separator: " · ")).font(Theme.font(11)).foregroundStyle(Theme.muted)
                                    }
                                    Spacer()
                                    Button("Delete", role: .destructive) {
                                        pending = PendingCommand(title: "Delete Subscription", args: ["subscriptions", "delete", "--id", s.id, "--confirm"])
                                    }
                                }
                            }
                            HStack {
                                Button("Add Subscription", systemImage: "plus") { addingTo = g }
                                Spacer()
                                Button("Delete Group", role: .destructive) {
                                    pending = PendingCommand(title: "Delete Group", args: ["subscriptions", "groups", "delete", "--id", g.id, "--confirm"])
                                }
                            }
                        }
                    }
                    Section("New Group") {
                        HStack {
                            TextField("Reference name", text: $newGroup, prompt: Text("Pro"))
                            Button("Create") {
                                pending = PendingCommand(title: "Create Group", args: ["subscriptions", "groups", "create", "--app", app.id, "--reference-name", newGroup])
                            }
                            .disabled(newGroup.isEmpty)
                        }
                    }
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
            } else { ProgressView().frame(maxHeight: .infinity) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .commands($pending) { newGroup = ""; await load() }
        .sheet(item: $addingTo) { g in NewSubscription(group: g) { cmd in addingTo = nil; if let cmd { pending = cmd } } }
        .task { await load() }
    }

    func load() async {
        error = nil
        do {
            let gs = try await ASC.items(["subscriptions", "groups", "list", "--app", app.id])
            for g in gs { subs[g.id] = (try? await ASC.items(["subscriptions", "list", "--group-id", g.id])) ?? [] }
            groups = gs
        } catch { self.error = error.localizedDescription }
    }
}

struct NewSubscription: View {
    let group: Item
    let done: (PendingCommand?) -> Void
    @State private var name = ""
    @State private var productId = ""
    @State private var period = "ONE_MONTH"

    var body: some View {
        Form {
            Text(group.text("referenceName") ?? "Group").font(Theme.font(13, .semibold))
            TextField("Reference name", text: $name)
            TextField("Product ID", text: $productId)
            Picker("Renews every", selection: $period) {
                ForEach(["ONE_WEEK", "ONE_MONTH", "TWO_MONTHS", "THREE_MONTHS", "SIX_MONTHS", "ONE_YEAR"], id: \.self) {
                    Text($0.replacingOccurrences(of: "_", with: " ").capitalized).tag($0)
                }
            }
            HStack {
                Button("Cancel") { done(nil) }
                Spacer()
                Button("Create") {
                    done(PendingCommand(title: "Create Subscription", args: ["subscriptions", "create", "--group-id", group.id,
                                                                            "--reference-name", name, "--product-id", productId, "--subscription-period", period]))
                }
                .disabled(name.isEmpty || productId.isEmpty).keyboardShortcut(.defaultAction)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
    }
}

// One tab for both kinds of purchase, so the tab row stays short.
struct PurchasesTab: View {
    let app: ASCApp
    @State private var kind = 2

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $kind) { Text("App Price").tag(2); Text("In-App Purchases").tag(0); Text("Subscriptions").tag(1) }
                .pickerStyle(.segmented).labelsHidden().fixedSize().padding(.top, 8)
            switch kind {
            case 0: PurchasesView(app: app)
            case 1: SubscriptionsView(app: app)
            default: PriceView(app: app)
            }
        }
    }
}
