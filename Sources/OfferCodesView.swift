import AppKit
import SwiftUI

// Offer codes for one in-app purchase: free gift codes, on or off, one-time code batches you can copy out.
// Also the promoted-purchase switch, so the purchase can show on the App Store page.
struct OfferCodesSection: View {
    let app: ASCApp
    let iapID: String
    @Binding var pending: PendingCommand?
    @State private var codes: [Item] = []
    @State private var batches: [String: [Item]] = [:]
    @State private var name = ""
    @State private var countries = "US"
    @State private var quantity = 100
    @State private var expires = Date().addingTimeInterval(90 * 86400)
    @State private var promoted: Item?
    @State private var copied: String?

    var body: some View {
        Section("Offer Codes") {
            ForEach(codes) { c in
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(isOn: Binding(get: { c.bool("active") }, set: { on in
                        pending = PendingCommand(title: on ? "Turn On Code" : "Turn Off Code", args: ["iap", "offer-codes", "update", "--offer-code-id", c.id, "--active", on ? "true" : "false"])
                    })) { Text(c.text("name") ?? c.id).font(Theme.font(13, .semibold)) }
                    ForEach(batches[c.id] ?? []) { b in
                        HStack {
                            Text("\(b.text("numberOfCodes") ?? "?") codes, until \(b.text("expirationDate") ?? "?")").font(Theme.font(11)).foregroundStyle(Theme.muted)
                            Spacer()
                            Button(copied == b.id ? "Copied" : "Copy Codes") { Task { await copy(b) } }
                        }
                    }
                    HStack {
                        Stepper("\(quantity) one-time codes", value: $quantity, in: 1...10000, step: 50)
                        DatePicker("until", selection: $expires, in: Date()..., displayedComponents: .date).labelsHidden()
                        Button("Generate") {
                            pending = PendingCommand(title: "Generate Codes", args: ["iap", "offer-codes", "one-time-codes", "create", "--offer-code-id", c.id,
                                                                                    "--quantity", "\(quantity)", "--expiration-date", expires.formatted(.iso8601.year().month().day()),
                                                                                    "--environment", "PRODUCTION"])
                        }
                    }
                }
            }
            HStack {
                TextField("New free code name", text: $name, prompt: Text("FRIENDS"))
                TextField("Countries", text: $countries).frame(width: 100)
                Button("Create") {
                    let prices = countries.split(separator: ",").map { "\($0.trimmingCharacters(in: .whitespaces)):FREE" }.joined(separator: ",")
                    pending = PendingCommand(title: "Create Offer Code", args: ["iap", "offer-codes", "create", "--iap-id", iapID, "--name", name, "--prices", prices])
                }
                .disabled(name.isEmpty || countries.isEmpty)
            }
        }
        Section("App Store Page") {
            Toggle("Promote this purchase on the App Store", isOn: Binding(get: { promoted?.bool("enabled") ?? false }, set: { on in
                if let promoted {
                    pending = PendingCommand(title: on ? "Promote" : "Stop Promoting", args: ["iap", "promoted-purchases", "update", "--promoted-purchase-id", promoted.id, "--enabled", on ? "true" : "false"])
                } else {
                    pending = PendingCommand(title: "Promote", args: ["iap", "promoted-purchases", "create", "--app", app.id, "--product-id", iapID, "--enabled", "true", "--visible-for-all-users", "true"])
                }
            }))
        }
        .task(id: pending == nil) { if pending == nil { await load() } }
    }

    func load() async {
        codes = (try? await ASC.items(["iap", "offer-codes", "list", "--iap-id", iapID])) ?? []
        for c in codes { batches[c.id] = (try? await ASC.items(["iap", "offer-codes", "one-time-codes", "list", "--offer-code-id", c.id])) ?? [] }
        // ponytail: one promoted purchase per product, found by its product id in the raw JSON; decode the relationship if apps start promoting several
        promoted = nil
        if let data = try? await ASC.run(["iap", "promoted-purchases", "list", "--app", app.id]),
           String(decoding: data, as: UTF8.self).contains(iapID) {
            struct R: Decodable { let data: [Item]? }
            promoted = (try? JSONDecoder().decode(R.self, from: data))?.data?.first
        }
    }

    // Codes come back as JSON; copy them one per line.
    func copy(_ b: Item) async {
        guard let data = try? await ASC.run(["iap", "offer-codes", "one-time-codes", "values", "--one-time-code-id", b.id]),
              let text = String(data: data, encoding: .utf8) else { return }
        let codes = text.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init).filter { $0.count >= 8 && $0.uppercased() == $0 }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(codes.isEmpty ? text : codes.joined(separator: "\n"), forType: .string)
        copied = b.id
    }
}
