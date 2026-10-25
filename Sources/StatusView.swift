import SwiftUI

struct StatusView: View {
    let app: ASCApp
    @State private var status: Status?
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let s = status {
                    HStack {
                        Circle().fill(color(s.summary.health)).frame(width: 12, height: 12)
                        Text(s.summary.nextAction ?? "Nothing to do")
                    }
                    ForEach(s.summary.blockers ?? [], id: \.self) { Label($0, systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
                    row("App Store", [s.appstore?.version, s.appstore?.state, s.appstore?.platform])
                    row("Review", [s.review?.state, s.review?.submittedDate])
                    row("Latest build", [s.builds?.latest?.version, s.builds?.latest?.buildNumber, s.builds?.latest?.processingState])
                    ChecklistSection(app: app)
                    SalesSection(app: app)
                    HStack {
                        link("App Store Connect", s.links?.appStoreConnect)
                        link("TestFlight", s.links?.testFlight)
                        link("Review", s.links?.review)
                    }
                } else if let error {
                    Text(error).foregroundStyle(.red).textSelection(.enabled)
                } else {
                    ProgressView()
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        
        .task { await load() }
    }

    func load() async {
        error = nil
        do { status = try await ASC.status(app.id) } catch { self.error = error.localizedDescription }
    }

    func row(_ title: String, _ parts: [String?]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(parts.compactMap { $0 }.joined(separator: " · ").ifEmpty("-"))
        }
    }

    @ViewBuilder func link(_ title: String, _ url: String?) -> some View {
        if let url, let u = URL(string: url) { Link(title, destination: u).foregroundStyle(Theme.accent) }
    }

    func color(_ h: String?) -> Color {
        switch h { case "green": .green; case "yellow": .yellow; case "red": .red; default: .gray }
    }
}

