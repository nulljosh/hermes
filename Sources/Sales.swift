import Charts
import SwiftUI

// Sales (4.0): last month's downloads and proceeds from Apple's monthly sales summary, through asc.
enum Sales {
    struct Row: Equatable { let appleId: String; let type: String; let units: Int; let proceeds: Double }
    struct Totals: Equatable { var downloads = 0, redownloads = 0; var proceeds = 0.0 }

    /// Apple's tab-separated summary. Product types starting 1 are first downloads, 3 redownloads; 7 (updates) is skipped.
    static func parse(_ tsv: String) -> [Row] {
        let lines = tsv.split(whereSeparator: \.isNewline).map { $0.split(separator: "\t", omittingEmptySubsequences: false).map(String.init) }
        guard let head = lines.first, let id = head.firstIndex(of: "Apple Identifier"), let t = head.firstIndex(of: "Product Type Identifier"),
              let u = head.firstIndex(of: "Units"), let p = head.firstIndex(of: "Developer Proceeds") else { return [] }
        return lines.dropFirst().compactMap { c in
            guard c.count > max(id, t, u, p) else { return nil }
            return Row(appleId: c[id], type: c[t], units: Int(Double(c[u]) ?? 0), proceeds: (Double(c[p]) ?? 0) * (Double(c[u]) ?? 0))
        }
    }

    static func totals(_ rows: [Row], app: String) -> Totals {
        rows.filter { $0.appleId == app }.reduce(into: Totals()) { t, r in
            if r.type.hasPrefix("1") || r.type == "F1" { t.downloads += r.units }
            if r.type.hasPrefix("3") || r.type == "F3" { t.redownloads += r.units }
            t.proceeds += r.proceeds
        }
    }

    static var lastMonth: String { month(ago: 1) }

    /// "YYYY-MM" for n months back; Apple publishes a month's summary after it ends, so 1 is the newest there is.
    static func month(ago n: Int) -> String {
        let d = Calendar.current.date(byAdding: .month, value: -n, to: .now)!
        let c = Calendar.current.dateComponents([.year, .month], from: d)
        return String(format: "%04d-%02d", c.year!, c.month!)
    }

    /// One download per month for the whole account, cached on disk: every app reads the same file.
    static func month(_ ym: String) async throws -> [Row] {
        let dir = URL.cachesDirectory.appendingPathComponent("Hermes/sales"), file = dir.appendingPathComponent("\(ym).tsv")
        if let s = try? String(contentsOf: file, encoding: .utf8) { return parse(s) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        struct C: Decodable { let vendor_number: String? }
        let config = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".asc/config.json")
        guard let vendor = (try? JSONDecoder().decode(C.self, from: Data(contentsOf: config)))?.vendor_number else {
            throw NSError(domain: "Hermes", code: 1, userInfo: [NSLocalizedDescriptionKey: "No vendor number in asc's config. Add it from Payments and Financial Reports."])
        }
        // --output is the report file here, so the JSON flag asc.run adds would be wrong: build the call by hand.
        _ = try await ASC.run(["analytics", "sales", "--vendor", vendor, "--type", "SALES", "--subtype", "SUMMARY", "--frequency", "MONTHLY",
                               "--date", ym, "--decompress", "--allow-missing", "--output", file.path], json: false, timeout: 180)
        return parse((try? String(contentsOf: file, encoding: .utf8)) ?? "")
    }
}

struct SalesSection: View {
    let app: ASCApp
    @State private var totals: Sales.Totals?
    @State private var history: [(month: String, downloads: Int)] = []
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Sales, \(Sales.lastMonth)").font(Theme.font(13, .semibold))
            if let t = totals {
                Text("\(t.downloads) downloads, \(t.redownloads) redownloads, \(t.proceeds, format: .currency(code: "USD")) proceeds")
                if history.count > 1 {
                    // Six months of first downloads (9.0), one cached report per month for the whole account.
                    Chart(history, id: \.month) { BarMark(x: .value("Month", $0.month), y: .value("Downloads", $0.downloads)).foregroundStyle(Theme.accent) }
                        .frame(height: 120)
                }
            } else if let error {
                Text(error.contains("forbidden") || error.contains("does not allow")
                     ? "Sales need an App Store Connect key with the Finance or Sales role. Add one in Accounts." : error)
                    .foregroundStyle(Theme.muted).textSelection(.enabled)
            } else { ProgressView().controlSize(.small) }
        }
        .task {
            do {
                totals = Sales.totals(try await Sales.month(Sales.lastMonth), app: app.id)
                var h: [(month: String, downloads: Int)] = []
                for n in (1...6).reversed() {
                    let m = Sales.month(ago: n)
                    if let rows = try? await Sales.month(m) { h.append((m, Sales.totals(rows, app: app.id).downloads)) }
                }
                history = h
            } catch { self.error = error.localizedDescription }
        }
    }
}
