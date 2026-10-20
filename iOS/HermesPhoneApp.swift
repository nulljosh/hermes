import CoreText
import Security
import SwiftUI

// Hermes on iPhone: the app list and one app's versions, builds and reviews, read only, straight from Apple's API.

@main
struct HermesPhoneApp: App {
    init() {
        for url in Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [] {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        KeyStore.importDebugKey()
    }

    var body: some Scene {
        WindowGroup { PhoneRoot() }
    }
}

/// The API key lives in the Keychain, synced between your devices by iCloud Keychain and nowhere else.
enum KeyStore {
    private static let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "com.nulljosh.hermes.asc",
                                              kSecAttrAccount as String: "key", kSecAttrSynchronizable as String: kCFBooleanTrue!]

    static func load() -> ASCKey? {
        var q = base; q[kSecReturnData as String] = true
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return nil }
        return try? JSONDecoder().decode(ASCKey.self, from: d)
    }

    static func save(_ key: ASCKey) {
        delete()
        var q = base
        q[kSecValueData as String] = try? JSONEncoder().encode(key)
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(q as CFDictionary, nil)
    }

    static func delete() { SecItemDelete(base as CFDictionary) }

    /// Debug builds only: `simctl launch` can pass a key in the environment for testing. Release builds ignore it.
    static func importDebugKey() {
        #if DEBUG
        let env = ProcessInfo.processInfo.environment
        guard let id = env["HERMES_KEY_ID"], let issuer = env["HERMES_ISSUER_ID"], let b64 = env["HERMES_KEY_PEM_B64"],
              let pemData = Data(base64Encoded: b64) else { return }
        save(ASCKey(keyID: id, issuerID: issuer, pem: String(decoding: pemData, as: UTF8.self)))
        #endif
    }
}

/// Debug-only QA switch: HERMES_SCREEN=onboarding|status|settings opens that screen on launch.
let qaScreen: String = {
    #if DEBUG
    return ProcessInfo.processInfo.environment["HERMES_SCREEN"] ?? ""
    #else
    return ""
    #endif
}()

struct PhoneRoot: View {
    @State private var key = qaScreen == "onboarding" ? nil : KeyStore.load()
    @State private var fleet: Fleet?
    @State private var splashDone = false
    @AppStorage("onboarded") private var onboarded = false

    var body: some View {
        ZStack {
            Group {
                if let fleet { MainTabs(fleet: fleet) { KeyStore.delete(); key = nil; self.fleet = nil } }
                else if !onboarded || qaScreen == "onboarding" { OnboardingView { withAnimation { onboarded = true } } }
                else { KeyView { KeyStore.save($0); key = $0; fleet = Fleet(client: ASCClient(key: $0)) } }
            }
            if !splashDone {
                SplashView { withAnimation(.easeOut(duration: 0.25)) { splashDone = true } }.transition(.opacity).zIndex(1)
            }
        }
        .tint(Theme.accent)
        .font(Theme.font(17))
        .onAppear { if let key, fleet == nil { fleet = Fleet(client: ASCClient(key: key)) } }
    }
}

struct MainTabs: View {
    let fleet: Fleet
    var onDisconnect: () -> Void
    @State private var tab = qaScreen == "status" ? 1 : qaScreen == "settings" ? 2 : 0

    var body: some View {
        TabView(selection: $tab) {
            AppsView(fleet: fleet).tabItem { Label("Apps", systemImage: "square.grid.2x2") }.tag(0)
            StatusView(fleet: fleet).tabItem { Label("Status", systemImage: "circle.dotted.circle") }.tag(1)
            SettingsView(fleet: fleet, onDisconnect: onDisconnect).tabItem { Label("Settings", systemImage: "gearshape") }.tag(2)
        }
        .task { if fleet.apps.isEmpty { await fleet.load() } }
    }
}
