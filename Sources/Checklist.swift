import SwiftUI

// Release checklist (4.0): asc validate for every version that is not live yet, its steps in the order to fix them.
struct Validation: Decodable {
    struct Summary: Decodable { let errors: Int; let warnings: Int; let blocking: Int }
    struct Step: Decodable, Identifiable { let order: Int; let blocking: Bool; let severity: String; let message: String; let remediation: String?; var id: Int { order } }
    struct Plan: Decodable { let steps: [Step] }
    let platform: String
    let versionString: String
    let summary: Summary
    let remediation: Plan?

    var verdict: String {
        summary.blocking > 0 ? "\(summary.blocking) blocking" : summary.errors + summary.warnings > 0 ? "\(summary.errors + summary.warnings) to look at" : "Ready to submit"
    }
}

struct ChecklistSection: View {
    let app: ASCApp
    @State private var results: [Validation]?
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Release checklist").font(Theme.font(13, .semibold))
            if let results {
                if results.isEmpty { Text("Every version is live. Nothing to check.").foregroundStyle(Theme.muted) }
                ForEach(results, id: \.platform) { v in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Circle().fill(v.summary.blocking > 0 ? Theme.bad : v.summary.errors + v.summary.warnings > 0 ? Theme.pending : Theme.live).frame(width: 8, height: 8)
                            Text("\(v.versionString) on \(Theme.platform(v.platform))").font(Theme.font(12, .semibold))
                            Text(v.verdict).font(Theme.font(12)).foregroundStyle(Theme.muted)
                        }
                        ForEach(v.remediation?.steps ?? []) { s in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(s.order). \(s.message)").foregroundStyle(s.blocking ? Theme.bad : .primary)
                                if let r = s.remediation { Text(r).font(Theme.font(11)).foregroundStyle(Theme.muted).textSelection(.enabled) }
                            }
                        }
                    }
                }
            } else if let error {
                Text(error).foregroundStyle(Theme.bad).textSelection(.enabled)
            } else {
                Button("Check what blocks submitting") { Task { await run() } }
            }
        }
    }

    /// Read-only: validate never writes, so it runs even in read-only mode.
    func run() async {
        do {
            let open = try await ASC.versions(app.id).filter { !$0.state.hasPrefix("READY_FOR") && $0.state != "ACCEPTED" }
            var out: [Validation] = []
            for v in open {
                let d = try await ASC.run(["validate", "--app", app.id, "--version", v.version, "--platform", v.platform], timeout: 180)
                out.append(try JSONDecoder().decode(Validation.self, from: d))
            }
            results = out
        } catch { self.error = error.localizedDescription }
    }
}
