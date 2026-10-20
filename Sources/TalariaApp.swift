import CoreText
import SwiftUI

@main
struct TalariaApp: App {
    init() {
        for url in Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [] {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    var body: some Scene {
        WindowGroup { RootView() }
            .windowStyle(.hiddenTitleBar)
            .defaultSize(width: 920, height: 620)
        Settings { SettingsView() }
    }
}

struct SettingsView: View {
    @AppStorage("readOnly") private var readOnly = true

    var body: some View {
        Form {
            Toggle("Read-only mode", isOn: $readOnly)
            Text("While this is on, Talaria can look at everything and change nothing. Turn it off to save, submit and release.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .frame(width: 420)
    }
}
