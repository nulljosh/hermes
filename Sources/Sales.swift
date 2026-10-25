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

    static var lastMonth: String {
        let d = Calendar.current.date(byAdding: .month, value: -1, to: .now)!
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
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Sales, \(Sales.lastMonth)").font(Theme.font(13, .semibold))
            if let t = totals {
                Text("\(t.downloads) downloads, \(t.redownloads) redownloads, \(t.proceeds, format: .currency(code: "USD")) proceeds")
            } else if let error {
                Text(error.contains("forbidden") || error.contains("does not allow")
                     ? "Sales need an App Store Connect key with the Finance or Sales role. Add one in Accounts." : error)
                    .foregroundStyle(Theme.muted).textSelection(.enabled)
            } else { ProgressView().controlSize(.small) }
        }
        .task {
            do { totals = Sales.totals(try await Sales.month(Sales.lastMonth), app: app.id) } catch { self.error = error.localizedDescription }
        }
    }
}
