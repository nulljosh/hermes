import Foundation

// Drafting for Resolve All: Writer turns each rejection and its facts into a reply and an issue; the drafts are kept on disk.

enum Drafter {
    static var available: Bool { get async { await Writer.available } }

    static func draft(_ items: [Resolution]) async throws -> [Resolution] {
        guard !items.isEmpty else { return items }
        let fleet = await Facts.fleet()
        var out: [Resolution] = []
        for r in items {
            let found = await Facts.gather(r.app, repo: r.repo, fleet: fleet)
            let d = try await Writer.write(app: "\(r.app.name) \(r.version)", reasons: r.reasons.joined(separator: "; "),
                                           replied: r.replied, facts: found.sheet, apple: r.apple)
            var r = r
            r.reply = unclaim(d.reply); r.issueTitle = d.title; r.issueBody = d.body
            if r.repo.isEmpty { r.repo = found.repo }
            out.append(r)
        }
        return out
    }

    /// Small models still write "We have revised the app" when nothing changed. Any sentence claiming a change is dropped.
    /// ponytail: keyword match, misses unusual verbs; the [bracket] gate and the confirm dialog still stand.
    static func unclaim(_ reply: String) -> String {
        let claim = #"\b(we|i)(['’]ve| have| had)?\s+((now|also|just|already|since|recently)\s+)*(revised|updated|changed|fixed|removed|added|improved|resolved|addressed|modified|implemented|redesigned|rebuilt|corrected)\b"#
        var out: [String] = []
        reply.enumerateSubstrings(in: reply.startIndex..., options: .bySentences) { s, _, _, _ in
            guard let s else { return }
            if s.range(of: claim, options: [.regularExpression, .caseInsensitive]) == nil { out.append(s) }
        }
        return out.joined().trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Drafts survive a relaunch, so an edit is never lost and no draft is paid for twice.
/// dry-run.md beside them is the whole run in one readable page: what Apple said, the reply, the issue.
enum SavedDrafts {
    struct Draft: Codable { var reply, issueTitle, issueBody: String }
    static let dir = URL.cachesDirectory.appendingPathComponent("Hermes/review")
    static var url: URL { dir.appendingPathComponent("drafts.json") }
    // ponytail: a new Apple message in the same thread changes the length, which retires the old draft.
    static func key(_ r: Resolution) -> String { "\(r.thread)|\(r.apple.utf8.count)" }
    static func load() -> [String: Draft] { (try? JSONDecoder().decode([String: Draft].self, from: Data(contentsOf: url))) ?? [:] }

    static func apply(_ rows: [Resolution]) -> [Resolution] {
        let saved = load()
        return rows.map { r in
            guard let d = saved[key(r)] else { return r }
            var r = r; r.reply = d.reply; r.issueTitle = d.issueTitle; r.issueBody = d.issueBody
            return r
        }
    }

    static func save(_ rows: [Resolution]) {
        var all = load()
        for r in rows where !(r.reply + r.issueTitle + r.issueBody).isEmpty {
            all[key(r)] = Draft(reply: r.reply, issueTitle: r.issueTitle, issueBody: r.issueBody)
        }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? JSONEncoder().encode(all).write(to: url, options: .atomic)
        try? dryRun(rows).write(to: dir.appendingPathComponent("dry-run.md"), atomically: true, encoding: .utf8)
    }

    static func dryRun(_ rows: [Resolution]) -> String {
        rows.map { r in
            """
            ## \(r.app.name) \(r.version)\(r.include ? "" : " (skipped)")
            Reasons: \(r.reasons.joined(separator: "; "))

            Apple said:
            \(r.apple.split(separator: "\n").map { "> " + $0 }.joined(separator: "\n"))

            Reply:
            \(r.reply.isEmpty ? "(none)" : r.reply)

            Issue: \(r.issueTitle.isEmpty ? "(none)" : r.issueTitle)\(r.repo.isEmpty ? "" : " in " + r.repo)
            \(r.issueBody)
            """
        }.joined(separator: "\n\n---\n\n")
    }
}
