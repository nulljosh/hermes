import SwiftUI

// The app's own price: what customers pay and what you get, and a new price from a chosen day.
struct PriceView: View {
    let app: ASCApp
    @State private var price: String?
    @State private var proceeds: String?
    @State private var currency = "USD"
    @State private var free = false
    @State private var newPrice = "0.99"
    @State private var start = Date()
    @State private var error: String?
    @State private var pending: PendingCommand?

    var body: some View {
        Form {
            Section("Now (United States)") {
                if let error { Text(error).foregroundStyle(Theme.bad).textSelection(.enabled) }
                else if let price {
                    LabeledContent("Customers pay", value: free ? "Free" : "\(price) \(currency)")
                    if !free, let proceeds { LabeledContent("You get", value: "\(proceeds) \(currency)") }
                } else { ProgressView() }
            }
            Section("Change the Price") {
                Picker("Price", selection: $newPrice) {
                    Text("Free").tag("free"); Text("0.99").tag("0.99"); Text("1.99").tag("1.99"); Text("2.99").tag("2.99"); Text("4.99").tag("4.99")
                }
                DatePicker("From", selection: $start, in: Date()..., displayedComponents: .date)
                Text("Other countries follow the US price automatically.").font(.caption).foregroundStyle(.secondary)
                Button("Set Price") {
                    let day = start.formatted(.iso8601.year().month().day())
                    pending = PendingCommand(title: "Set Price", args: ["pricing", "schedule", "create", "--app", app.id, "--base-territory", "USA", "--start-date", day]
                        + (newPrice == "free" ? ["--free"] : ["--price", newPrice]))
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
        do {
            let o = try JSONSerialization.jsonObject(with: await ASC.run(["pricing", "current", "--app", app.id])) as? [String: Any] ?? [:]
            price = o["customerPrice"] as? String ?? "0"; proceeds = o["proceeds"] as? String
            currency = o["currency"] as? String ?? "USD"; free = o["isFree"] as? Bool ?? false
        } catch { self.error = error.localizedDescription }
    }
}
