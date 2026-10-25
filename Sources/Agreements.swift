import Foundation

// The banner Apple shows when a new license agreement is waiting, read with asc's web session.
enum Agreements {
    struct Status: Decodable {
        struct A: Decodable { let title: String; let status: String?; let pending: Bool?; let dateAgreeBy: String? }
        let pending: Bool?
        let contractMessages: [String]?
        let agreements: [A]?
    }

    /// One line for the banner, or nil when every agreement is accepted.
    static func notice(from data: Data) -> String? {
        guard let s = try? JSONDecoder().decode(Status.self, from: data) else { return nil }
        if let a = s.agreements?.first(where: { $0.pending == true || ($0.status ?? "active") != "active" }) {
            let by = a.dateAgreeBy.map { " by " + $0.prefix(10) } ?? ""
            return "Apple has a new \(a.title) to accept\(by). Until you do, nothing can be submitted."
        }
        if s.pending == true || !(s.contractMessages ?? []).isEmpty { return "Apple has a message about your agreements." }
        return nil
    }

    /// Quiet on failure: an expired web session should not put a warning on the app list.
    static func check() async -> String? {
        guard let d = try? await ASC.run(["web", "agreements", "status"], timeout: 60) else { return nil }
        return notice(from: d)
    }
}
