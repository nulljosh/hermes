import SwiftUI

enum Tab: String, CaseIterable, Identifiable {
    case status = "Status", versions = "Versions", metadata = "Metadata", media = "Media", builds = "Builds", testflight = "TestFlight", reviews = "Reviews", submissions = "Submissions", purchases = "Purchases"
    var id: String { rawValue }
}

struct DetailView: View {
    let app: ASCApp
    let store: Store
    let back: () -> Void
    // QA launch argument: -tab <name> picks the starting tab.
    @State private var tab = Tab(rawValue: UserDefaults.standard.string(forKey: "tab") ?? "") ?? .status

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: back) { Image(systemName: "chevron.left") }
                    .buttonStyle(.plain).foregroundStyle(Theme.muted)
                AppIcon(app: app, url: store.icons[app.id], size: 32)
                Text(app.name).font(Theme.font(16, .semibold)).lineLimit(1)
                Spacer()
            }
            .padding([.horizontal, .top], 12)
            // Tabs get their own row and size to their labels, so nine of them fit.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(Tab.allCases) { t in
                        Button { tab = t } label: {
                            Text(t.rawValue).font(Theme.font(12, tab == t ? .semibold : .medium))
                                .foregroundStyle(tab == t ? Theme.text : Theme.muted)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(tab == t ? Theme.surface : .clear, in: Capsule())
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
            }
            .padding(.vertical, 8)
            Divider().overlay(Theme.line)
            switch tab {
            case .status: StatusView(app: app)
            case .versions: VersionsView(app: app)
            case .metadata: MetadataView(app: app)
            case .media: MediaView(app: app)
            case .builds: BuildsView(app: app)
            case .testflight: TestFlightView(app: app)
            case .reviews: ReviewsView(app: app)
            case .submissions: SubmissionsView(app: app)
            case .purchases: ItemList(args: ["iap", "list", "--app", app.id],
                                     title: ["name"], sub: ["productId", "inAppPurchaseType", "state"], state: "state")
            }
        }
    }
}

struct ItemList: View {
    let args: [String]
    let title: [String], sub: [String]
    let state: String?
    @State private var items: [Item]?
    @State private var error: String?

    var body: some View {
        Group {
            if let error { Text(error).foregroundStyle(Theme.bad).padding().textSelection(.enabled) }
            else if let items {
                if items.isEmpty { Text("Nothing here yet.").foregroundStyle(Theme.muted).frame(maxWidth: .infinity, maxHeight: .infinity) }
                else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(items) { row($0) }
                        }
                    }
                }
            } else { ProgressView().frame(maxHeight: .infinity) }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .task(id: args) {
            items = nil; error = nil
            do { items = try await ASC.items(args) } catch { self.error = error.localizedDescription }
        }
    }

    func row(_ i: Item) -> some View {
        HStack(spacing: 8) {
            if let state { Circle().fill(Theme.stateColor(i.text(state))).frame(width: 8, height: 8) }
            VStack(alignment: .leading, spacing: 2) {
                Text(title.compactMap(i.text).joined(separator: " · ").ifEmpty(i.id)).font(Theme.font(13, .semibold))
                Text(sub.compactMap(i.text).joined(separator: " · ")).font(Theme.font(11)).foregroundStyle(Theme.muted).lineLimit(2)
            }
            Spacer()
        }
        .padding(.horizontal, 8).padding(.vertical, 10)
        .contentShape(Rectangle())
        .hoverable()
    }
}

extension String {
    func ifEmpty(_ s: String) -> String { isEmpty ? s : self }
}
