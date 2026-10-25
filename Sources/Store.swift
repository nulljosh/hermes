import SwiftUI

@MainActor @Observable
final class Store {
    /// One store for the window, the menu bar and Shortcuts, so they never disagree.
    static let shared = Store()
    var apps: [ASCApp] = []
    var versions: [String: [PlatformVersion]] = [:]
    var icons: [String: URL] = [:]
    var error: String?
    var loading = false

    func load() async {
        loading = true; error = nil
        defer { loading = false }
        do { apps = try await ASC.apps() } catch { self.error = error.localizedDescription; return }
        // ponytail: 4 asc processes at a time; 60 at once made some calls fail. Raise if asc gets faster.
        await withTaskGroup(of: Void.self) { g in
            var queue = apps[...]
            func next() {
                guard let app = queue.popFirst() else { return }
                g.addTask { [self] in
                    let v = try? await ASC.versions(app.id)
                    var i = await ASC.icon(bundleId: app.bundleId)
                    if i == nil { i = await ASC.buildIcon(app.id) }
                    await MainActor.run { versions[app.id] = v ?? []; icons[app.id] = i }
                }
            }
            for _ in 0..<4 { next() }
            while await g.next() != nil { next() }
        }
        Watch.check(self)
    }
}
