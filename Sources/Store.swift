import SwiftUI

@MainActor @Observable
final class Store {
    var apps: [ASCApp] = []
    var versions: [String: [PlatformVersion]] = [:]
    var icons: [String: URL] = [:]
    var error: String?
    var loading = false

    func load() async {
        loading = true; error = nil
        defer { loading = false }
        do { apps = try await ASC.apps() } catch { self.error = error.localizedDescription; return }
        await withTaskGroup(of: Void.self) { g in
            for app in apps {
                g.addTask { [self] in
                    let v = try? await ASC.versions(app.id)
                    var i = await ASC.icon(bundleId: app.bundleId)
                    if i == nil { i = await ASC.buildIcon(app.id) }
                    await MainActor.run { versions[app.id] = v ?? []; icons[app.id] = i }
                }
            }
        }
    }
}
