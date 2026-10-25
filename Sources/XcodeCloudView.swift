import SwiftUI

// Xcode Cloud (6.0): each workflow with its last runs, and a confirmed button to start one.
struct XcodeCloudView: View {
    let app: ASCApp
    @State private var workflows: [Item]?
    @State private var runs: [String: [Item]] = [:]
    @State private var error: String?
    @State private var pending: PendingCommand?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let workflows {
                    if workflows.isEmpty { Text("No Xcode Cloud workflows for this app.").foregroundStyle(Theme.muted) }
                    ForEach(workflows) { w in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(w.text("name") ?? w.id).font(Theme.font(14, .semibold))
                                if w.text("isEnabled") == "false" { Text("off").font(Theme.font(11)).foregroundStyle(Theme.muted) }
                                Spacer()
                                Button("Start Build") {
                                    pending = PendingCommand(title: "Start \(w.text("name") ?? "workflow")",
                                                             args: ["xcode-cloud", "run", "--app", app.id, "--workflow-id", w.id])
                                }
                            }
                            let r = runs[w.id] ?? []
                            if r.isEmpty { Text("No runs yet.").font(Theme.font(12)).foregroundStyle(Theme.muted) }
                            ForEach(r) { run in
                                HStack(spacing: 8) {
                                    Circle().fill(XcodeCloudView.color(run)).frame(width: 8, height: 8)
                                    Text("#\(run.text("number") ?? "?")").font(Theme.font(12, .semibold))
                                    Text(XcodeCloudView.words(run)).font(Theme.font(12))
                                    Spacer()
                                    Text(String((run.text("createdDate") ?? "").prefix(16)).replacingOccurrences(of: "T", with: " "))
                                        .font(Theme.font(11)).foregroundStyle(Theme.muted)
                                }
                            }
                        }
                    }
                } else if let error {
                    Text(error.lowercased().contains("product") || error.contains("404") ? "This app is not set up in Xcode Cloud." : error)
                        .foregroundStyle(Theme.muted).textSelection(.enabled)
                } else { ProgressView() }
            }
            .padding(24).frame(maxWidth: .infinity, alignment: .leading)
        }
        .commands($pending) { await load() }
        .task { await load() }
    }

    /// Running beats finished; a finished run reads its completion status.
    static func words(_ run: Item) -> String {
        let progress = run.text("executionProgress") ?? ""
        if progress != "COMPLETE" { return progress.lowercased().ifEmpty("pending") }
        return (run.text("completionStatus") ?? "complete").lowercased()
    }

    static func color(_ run: Item) -> Color {
        switch run.text("completionStatus") {
        case "SUCCEEDED": Theme.live
        case "FAILED", "ERRORED": Theme.bad
        default: run.text("executionProgress") == "COMPLETE" ? Theme.idle : Theme.pending
        }
    }

    func load() async {
        error = nil
        do {
            let w = try await ASC.items(["xcode-cloud", "workflows", "list", "--app", app.id])
            for wf in w {
                runs[wf.id] = (try? await ASC.items(["xcode-cloud", "build-runs", "list", "--workflow-id", wf.id, "--sort", "-number", "--limit", "5"])) ?? []
            }
            workflows = w
        } catch { self.error = error.localizedDescription }
    }
}
