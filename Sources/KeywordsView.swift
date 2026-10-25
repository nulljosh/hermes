import SwiftUI

// Keyword tools (7.0): asc's keyword audit for each platform's newest version, one row per language.
struct KeywordAudit: Decodable {
    struct Locale: Decodable, Identifiable {
        let locale: String
        let keywordField: String?
        let keywordCount: Int?
        let usedBytes: Int?
        let remainingBytes: Int?
        let name: String?
        let subtitle: String?
        var id: String { locale }
        /// Words already in the name or subtitle are wasted in the keyword field: Apple indexes those fields anyway.
        var repeats: [String] {
            let shown = Set(((name ?? "") + " " + (subtitle ?? "")).lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init))
            return (keywordField ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }.filter(shown.contains)
        }
    }
    struct Check: Decodable, Identifiable { let severity: String?; let message: String?; let locale: String?; var id: String { (locale ?? "") + (message ?? "") } }
    let platform: String
    let versionString: String
    let locales: [Locale]
    let checks: [Check]?
}

struct KeywordsView: View {
    let app: ASCApp
    @State private var audits: [KeywordAudit]?
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let audits {
                    ForEach(audits, id: \.platform) { a in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(a.versionString) on \(Theme.platform(a.platform))").font(Theme.font(14, .semibold))
                            ForEach(a.checks ?? []) { c in
                                Label((c.locale.map { $0 + ": " } ?? "") + (c.message ?? ""), systemImage: "exclamationmark.triangle")
                                    .foregroundStyle(c.severity == "error" ? Theme.bad : Theme.pending)
                            }
                            ForEach(a.locales) { l in
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(l.locale).font(Theme.font(12, .semibold))
                                        Text("\(l.keywordCount ?? 0) keywords, \(l.remainingBytes ?? 0) of 100 characters left")
                                            .font(Theme.font(11)).foregroundStyle((l.remainingBytes ?? 0) > 20 ? Theme.pending : Theme.muted)
                                    }
                                    Text(l.keywordField ?? "none").font(Theme.font(12)).textSelection(.enabled)
                                    if !l.repeats.isEmpty {
                                        Text("Already in the name or subtitle: \(l.repeats.joined(separator: ", ")). Those slots can go to new words.")
                                            .font(Theme.font(11)).foregroundStyle(Theme.pending)
                                    }
                                }
                            }
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

    /// Read-only: the audit reads live keywords and changes nothing.
    func load() async {
        do {
            var out: [KeywordAudit] = []
            for v in try await ASC.versions(app.id) {
                let d = try await ASC.run(["metadata", "keywords", "audit", "--app", app.id, "--version", v.version, "--platform", v.platform], timeout: 120)
                out.append(try JSONDecoder().decode(KeywordAudit.self, from: d))
            }
            audits = out
        } catch { self.error = error.localizedDescription }
    }
}
