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
        WindowGroup { RootView() }
            .windowStyle(.hiddenTitleBar)
            .defaultSize(width: 1040, height: 680)
        Settings { SettingsView() }
    }
}

struct SettingsView: View {
    @AppStorage("readOnly") private var readOnly = true
    @AppStorage("appearance") private var appearance = "system"

    var body: some View {
        Form {
            Picker("Appearance", selection: $appearance) { Text("System").tag("system"); Text("Light").tag("light"); Text("Dark").tag("dark") }
            Toggle("Read-only mode", isOn: $readOnly)
            Text("While this is on, Hermes can look at everything and change nothing. Turn it off to save, submit and release.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .frame(width: 420)
    }
}
