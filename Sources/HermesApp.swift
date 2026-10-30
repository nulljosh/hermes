import UserNotifications
import CoreText
import SwiftUI

@main
struct HermesApp: App {
    init() {
        for url in Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [] {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    var body: some Scene {
        WindowGroup(id: "main") { RootView().task { await Watch.poll(Store.shared) } }
            .windowStyle(.hiddenTitleBar)
            .defaultSize(width: 1040, height: 680)
        Settings { SettingsView() }
        MenuBarExtra("Hermes", systemImage: "paperplane") { MenuBarView(store: Store.shared).font(Theme.font(12)) }
            .menuBarExtraStyle(.window)
    }
}

struct SettingsView: View {
    @AppStorage("readOnly") private var readOnly = true
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("notifyReview") private var notifyReview = false

    var body: some View {
        Form {
            HStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hermes").font(.title2.weight(.semibold))
                    Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Picker("Appearance", selection: $appearance) { Text("System").tag("system"); Text("Light").tag("light"); Text("Dark").tag("dark") }
            Toggle("Notify when a review state changes", isOn: $notifyReview)
                .onChange(of: notifyReview) { _, on in
                    // Asked only when turned on, so Hermes never pops a permission request by itself.
                    if on { UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in } }
                }
            Toggle("Read-only mode", isOn: $readOnly)
            Text("While this is on, Hermes can look at everything and change nothing. Turn it off to save, submit and release.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .frame(width: 420)
    }
}
