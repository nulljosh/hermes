import SwiftUI

@main
struct TillerApp: App {
    var body: some Scene {
        WindowGroup { RootView() }
            .windowStyle(.hiddenTitleBar)
            .defaultSize(width: 920, height: 620)
    }
}
