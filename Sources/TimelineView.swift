import SwiftUI

// Release timeline (4.2): every version on every platform, newest first, with the day it was made and where it ended up.
struct TimelineView: View {
    let app: ASCApp
    @State private var rows: [Item]?
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let rows {
                    if rows.isEmpty { Text("No versions yet.").foregroundStyle(Theme.muted).padding(16) }
                    ForEach(rows) { v in
                        let state = v.text("appVersionState") ?? v.text("appStoreState")
                        HStack(alignment: .top, spacing: 12) {
                            Text(String((v.text("createdDate") ?? "").prefix(10))).font(Theme.font(11, .medium)).foregroundStyle(Theme.muted)
                                .frame(width: 80, alignment: .leading)
                            VStack(spacing: 0) {
                                Circle().fill(Theme.stateColor(state)).frame(width: 9, height: 9)
                                Rectangle().fill(Theme.line).frame(width: 1).frame(maxHeight: .infinity)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(v.text("versionString") ?? "") on \(Theme.platform(v.text("platform") ?? ""))").font(Theme.font(13, .semibold))
                                Text(Watch.words(state ?? "")).font(Theme.font(11)).foregroundStyle(Theme.muted)
                            }
                            .padding(.bottom, 14)
                        }
                    }
                } else if let error {
                    Text(error).foregroundStyle(Theme.bad).textSelection(.enabled)
                } else { ProgressView() }
            }
            .padding(24).frame(maxWidth: .infinity, alignment: .leading)
        }
        .task { await load() }
    }

    func load() async {
        do {
            rows = try await ASC.items(["versions", "list", "--app", app.id, "--paginate"])
                .sorted { ($0.text("createdDate") ?? "") > ($1.text("createdDate") ?? "") }
        } catch { self.error = error.localizedDescription }
    }
}
