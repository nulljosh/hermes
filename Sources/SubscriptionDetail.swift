import SwiftUI

// One subscription: price for every country from a US base price, and its offers (introductory, promotional, win-back).
struct SubscriptionDetail: View {
    let sub: Item
    let price: IAPSummary?
    let back: () -> Void
    @State private var intro: [Item] = []
    @State private var promo: [Item] = []
    @State private var winBack: [Item] = []
    @State private var pending: PendingCommand?
    @State private var basePrice = "0.99"
    @State private var duration = "ONE_WEEK"
    @State private var mode = "FREE_TRIAL"
    @State private var periods = 1
    @State private var promoName = ""
    @State private var promoCode = ""
    @State private var winBackName = ""
    @State private var paidMonths = 6

    static let durations = ["THREE_DAYS", "ONE_WEEK", "TWO_WEEKS", "ONE_MONTH", "TWO_MONTHS", "THREE_MONTHS", "SIX_MONTHS", "ONE_YEAR"]
    static let modes = ["FREE_TRIAL", "PAY_AS_YOU_GO", "PAY_UP_FRONT"]
    static func words(_ s: String?) -> String? { s?.replacingOccurrences(of: "_", with: " ").lowercased() }

    var body: some View {
        Form {
            Section {
                HStack {
                    Button(action: back) { Label("Subscriptions", systemImage: "chevron.left") }.buttonStyle(.plain).foregroundStyle(Theme.accent)
                    Spacer()
                    Text(sub.text("state") ?? "").foregroundStyle(Theme.muted)
                }
            }
            Section("Price") {
                LabeledContent("Now (US)", value: IAPSummary.price(price?.currentPrice) ?? "No price")
                if let p = IAPSummary.price(price?.estimatedProceeds ?? price?.proceeds) { LabeledContent("You get", value: p) }
                HStack {
                    Picker("New US price", selection: $basePrice) { ForEach(["0.99", "1.99", "2.99", "4.99", "9.99"], id: \.self) { Text($0).tag($0) } }
                    Button("Set for Every Country") {
                        pending = PendingCommand(title: "Set Subscription Price", args: ["subscriptions", "pricing", "equalize", "--subscription-id", sub.id, "--base-price", basePrice, "--confirm"])
                    }
                }
            }
            Section("New Offer") {
                Picker("Mode", selection: $mode) { ForEach(Self.modes, id: \.self) { Text(Self.words($0)!.capitalized).tag($0) } }
                Picker("Lasts", selection: $duration) { ForEach(Self.durations, id: \.self) { Text(Self.words($0)!).tag($0) } }
                Stepper("\(periods) period\(periods == 1 ? "" : "s")", value: $periods, in: 1...12)
                Button("Add Introductory Offer, Every Country") {
                    pending = PendingCommand(title: "Add Introductory Offer", args: ["subscriptions", "offers", "introductory", "create", "--subscription-id", sub.id, "--all-territories",
                                                                                     "--offer-duration", duration, "--offer-mode", mode, "--number-of-periods", "\(periods)"])
                }
                HStack {
                    TextField("Promo name", text: $promoName, prompt: Text("Spring"))
                    TextField("Code", text: $promoCode, prompt: Text("SPRING")).frame(width: 100)
                    Button("Add Promotional") {
                        pending = PendingCommand(title: "Add Promotional Offer", args: ["subscriptions", "offers", "promotional", "create", "--subscription-id", sub.id, "--name", promoName,
                                                                                        "--offer-code", promoCode, "--offer-duration", duration, "--offer-mode", mode, "--number-of-periods", "\(periods)", "--prices", "US"])
                    }
                    .disabled(promoName.isEmpty || promoCode.isEmpty)
                }
                // ponytail: win-back as a US free trial only; paid win-back needs price point ids, add a picker when someone runs paid ones
                HStack {
                    TextField("Win-back name", text: $winBackName, prompt: Text("come-back"))
                    Stepper("after \(paidMonths) paid months", value: $paidMonths, in: 1...24)
                    Button("Add Win-Back Trial") {
                        pending = PendingCommand(title: "Add Win-Back Offer", args: ["subscriptions", "offers", "win-back", "create", "--subscription-id", sub.id, "--reference-name", winBackName,
                                                                                     "--offer-id", winBackName.uppercased(), "--duration", duration, "--offer-mode", "FREE_TRIAL", "--period-count", "\(periods)",
                                                                                     "--eligibility-paid-months", "\(paidMonths)", "--start-date", Date().formatted(.iso8601.year().month().day()),
                                                                                     "--priority", "NORMAL", "--territory", "USA"])
                    }
                    .disabled(winBackName.isEmpty)
                }
            }
            offers("Introductory Offers", intro, kind: "introductory") { o in
                [Self.words(o.text("offerMode")), o.text("numberOfPeriods").map { "\($0) ×" }, Self.words(o.text("duration")), o.text("startDate")]
            }
            offers("Promotional Offers", promo, kind: "promotional") { o in [o.text("name"), o.text("offerCode"), Self.words(o.text("offerMode")), Self.words(o.text("duration"))] }
            offers("Win-Back Offers", winBack, kind: "win-back") { o in [o.text("referenceName"), Self.words(o.text("offerMode")), Self.words(o.text("duration")), o.text("startDate")] }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .commands($pending) { promoName = ""; promoCode = ""; winBackName = ""; await load() }
        .task { await load() }
    }

    func offers(_ title: String, _ list: [Item], kind: String, parts: @escaping (Item) -> [String?]) -> some View {
        Section(title) {
            if list.isEmpty { Text("None yet.").foregroundStyle(Theme.muted) }
            ForEach(list) { o in
                HStack {
                    Text(parts(o).compactMap { $0 }.joined(separator: " · "))
                    Spacer()
                    Button("Delete", role: .destructive) { pending = PendingCommand(title: "Delete Offer", args: ["subscriptions", "offers", kind, "delete", "--id", o.id, "--confirm"]) }
                }
            }
        }
    }

    func load() async {
        async let i = ASC.items(["subscriptions", "offers", "introductory", "list", "--subscription-id", sub.id])
        async let p = ASC.items(["subscriptions", "offers", "promotional", "list", "--subscription-id", sub.id])
        async let w = ASC.items(["subscriptions", "offers", "win-back", "list", "--subscription-id", sub.id])
        intro = (try? await i) ?? []
        promo = (try? await p) ?? []
        winBack = (try? await w) ?? []
    }
}

// Billing grace period for the whole app: keeps paid access while Apple retries a failed renewal.
struct GracePeriodSection: View {
    let app: ASCApp
    @Binding var pending: PendingCommand?
    @State private var grace: Item?

    var body: some View {
        Section("Billing Grace Period") {
            Toggle("Keep access while a renewal payment is retried", isOn: Binding(get: { grace?.bool("optIn") ?? false }, set: { on in
                pending = PendingCommand(title: on ? "Turn On Grace Period" : "Turn Off Grace Period", args: ["subscriptions", "grace-periods", "update", "--id", app.id, "--opt-in", on ? "true" : "false"])
            }))
            Picker("Length", selection: Binding(get: { grace?.text("duration") ?? "SIXTEEN_DAYS" }, set: { d in
                pending = PendingCommand(title: "Set Grace Period", args: ["subscriptions", "grace-periods", "update", "--id", app.id, "--duration", d])
            })) { Text("3 days").tag("THREE_DAYS"); Text("16 days").tag("SIXTEEN_DAYS"); Text("28 days").tag("TWENTY_EIGHT_DAYS") }
            Picker("Applies to", selection: Binding(get: { grace?.text("renewalType") ?? "ALL_RENEWALS" }, set: { r in
                pending = PendingCommand(title: "Set Grace Period", args: ["subscriptions", "grace-periods", "update", "--id", app.id, "--renewal-type", r])
            })) { Text("All renewals").tag("ALL_RENEWALS"); Text("Paid to paid only").tag("PAID_TO_PAID_ONLY") }
        }
        // The grace period's id is the app's id.
        .task(id: pending == nil) { if pending == nil { grace = try? await ASC.one(["subscriptions", "grace-periods", "view", "--id", app.id]) } }
    }
}
