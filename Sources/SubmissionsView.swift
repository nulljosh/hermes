import SwiftUI

// Review submissions with their outcomes: submit drafts, cancel ones in review, start new ones.
struct Submission: Decodable, Identifiable {
    struct Part: Decodable { let id: String; let state: String?; let type: String?; let resourceId: String? }
    let submissionId: String
    let versionString: String?
    let platform: String?
    let state: String?
    let submittedDate: String?
    let outcome: String?
    let items: [Part]?
    var id: String { submissionId }
    var rejected: Bool { (outcome ?? state ?? "").lowercased().contains("reject") || state == "UNRESOLVED_ISSUES" }
}

struct SubmissionsView: View {
    let app: ASCApp
    @State private var subs: [Submission]?
    @State private var error: String?
    @State private var rejectedOnly = false
    @State private var pending: PendingCommand?
    @State private var creating = false

    var shown: [Submission] { (subs ?? []).filter { !rejectedOnly || $0.rejected } }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Toggle("Rejections only", isOn: $rejectedOnly).toggleStyle(.switch).controlSize(.small)
                Spacer()
                Button("New Submission", systemImage: "plus") { creating = true }
            }
            .padding(12)
            Divider().overlay(Theme.line)
            if let error { Text(error).foregroundStyle(Theme.bad).padding().textSelection(.enabled); Spacer() }
            else if subs != nil {
                if shown.isEmpty { Text(rejectedOnly ? "No rejections. Nice." : "No submissions yet.").foregroundStyle(Theme.muted).frame(maxHeight: .infinity) }
                else { ScrollView { LazyVStack(alignment: .leading, spacing: 0) { ForEach(shown) { row($0) } } } }
            } else { ProgressView().frame(maxHeight: .infinity) }
        }
        .commands($pending) { await load() }
        .sheet(isPresented: $creating) { NewSubmission(app: app) { cmd in creating = false; if let cmd { pending = cmd } }.font(Theme.font(13)) }
        .task { await load() }
    }

    func load() async {
        error = nil
        do { subs = try JSONDecoder().decode([Submission].self, from: await ASC.run(["review", "history", "--app", app.id, "--limit", "50"])) }
        catch { self.error = error.localizedDescription }
    }

    func color(_ s: Submission) -> Color {
        if s.rejected { return Theme.bad }
        switch s.outcome ?? "" {
        case "approved": return Theme.live
        case "", "complete": return Theme.idle
        default: return Theme.pending
        }
    }

    func row(_ s: Submission) -> some View {
        HStack(spacing: 8) {
            Circle().fill(color(s)).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(s.versionString ?? "No version") \(Theme.platform(s.platform ?? ""))").font(Theme.font(13, .semibold))
                Text([s.outcome?.replacingOccurrences(of: "_", with: " "), s.state, s.submittedDate.map { String($0.prefix(10)) },
                      "\(s.items?.count ?? 0) item\(s.items?.count == 1 ? "" : "s")"].compactMap { $0 }.joined(separator: " · "))
                    .font(Theme.font(11)).foregroundStyle(Theme.muted)
            }
            Spacer()
            if s.state == "READY_FOR_REVIEW" {
                Button("Submit") { pending = PendingCommand(title: "Submit for Review", args: ["review", "submissions-submit", "--id", s.id, "--confirm"]) }
            }
            if ["WAITING_FOR_REVIEW", "IN_REVIEW", "UNRESOLVED_ISSUES"].contains(s.state ?? "") {
                Button("Cancel Submission", role: .destructive) {
                    pending = PendingCommand(title: "Cancel Submission", args: ["review", "submissions-cancel", "--id", s.id, "--confirm"])
                }
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 10)
        .contentShape(Rectangle())
        .hoverable()
    }
}

struct NewSubmission: View {
    let app: ASCApp
    let done: (PendingCommand?) -> Void
    @State private var versions: [Item] = []
    @State private var versionID = ""

    var version: Item? { versions.first { $0.id == versionID } }

    var body: some View {
        Form {
            Picker("Version", selection: $versionID) {
                ForEach(versions) { v in Text("\(v.text("versionString") ?? "") \(Theme.platform(v.text("platform") ?? "")) · \(v.text("appVersionState") ?? "")").tag(v.id) }
            }
            Text("Creates a draft submission with this version in it. Submit it from the list when it is ready.").font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Cancel") { done(nil) }
                Spacer()
                Button("Create") {
                    guard let v = version else { return }
                    done(PendingCommand(title: "Create Submission",
                                        args: ["review", "submissions-create", "--app", app.id, "--platform", v.text("platform") ?? "IOS"],
                                        then: ["review", "items-add", "--submission", "{id}", "--item-type", "appStoreVersions", "--item-id", v.id]))
                }
                .disabled(version == nil).keyboardShortcut(.defaultAction)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .task {
            versions = (try? await ASC.items(["versions", "list", "--app", app.id, "--latest"])) ?? []
            versionID = versions.first { $0.text("appVersionState") == "PREPARE_FOR_SUBMISSION" }?.id ?? versions.first?.id ?? ""
        }
    }
}
