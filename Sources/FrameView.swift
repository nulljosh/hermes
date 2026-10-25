import AppKit
import SwiftUI

// Screenshot framing (8.0): a raw screenshot into an Apple device frame with a title, through asc and Koubou.
// Local only: the framed PNG lands in Caches and nothing goes to App Store Connect until you upload it.
struct FrameView: View {
    var close: () -> Void
    @State private var input: URL?
    @State private var device = "iphone-air"
    @State private var title = ""
    @State private var subtitle = ""
    @State private var picking = false
    @State private var busy = false
    @State private var result: URL?
    @State private var error: String?

    static let devices = ["iphone-air", "iphone-17-pro", "iphone-17-pro-max", "iphone-17", "iphone-16e", "ipad-pro-13", "ipad-pro-11",
                          "ipad-air-13", "ipad-air-11", "ipad-mini", "mac", "watch-series-11", "watch-ultra-3", "apple-tv"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Frame a Screenshot").font(Theme.font(15, .semibold))
            HStack {
                Button(input == nil ? "Choose PNG..." : input!.lastPathComponent) { picking = true }
                Picker("Device", selection: $device) { ForEach(Self.devices, id: \.self) { Text($0).tag($0) } }.frame(width: 240)
            }
            TextField("Title", text: $title).textFieldStyle(.roundedBorder)
            TextField("Subtitle", text: $subtitle).textFieldStyle(.roundedBorder)
            if let result, let img = NSImage(contentsOf: result) {
                Image(nsImage: img).resizable().scaledToFit().frame(maxHeight: 320)
                Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([result]) }
            }
            if let error { Text(error).foregroundStyle(Theme.bad).textSelection(.enabled) }
            HStack {
                Spacer()
                Button("Close", action: close)
                Button(busy ? "Framing..." : "Frame") { Task { await frame() } }.disabled(input == nil || busy).keyboardShortcut(.defaultAction)
            }
        }
        .padding(20).frame(width: 520)
        .fileImporter(isPresented: $picking, allowedContentTypes: [.png]) { if case .success(let u) = $0 { input = u; result = nil } }
    }

    func frame() async {
        guard let input else { return }
        busy = true; error = nil
        defer { busy = false }
        let dir = URL.cachesDirectory.appendingPathComponent("Hermes/framed")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let out = dir.appendingPathComponent(input.deletingPathExtension().lastPathComponent + "-" + device + ".png")
        // A solid brand background: asc's default behind text is a gradient, which the house design rules leave out.
        var args = ["screenshots", "frame", "--input", input.path, "--device", device, "--output-path", out.path, "--bg-color", "#0a0e19"]
        if !title.isEmpty { args += ["--title", title] }
        if !subtitle.isEmpty { args += ["--subtitle", subtitle] }
        // Koubou (kou) is a Python tool on the user's PATH; an app launched from Finder does not inherit that PATH.
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = "\(home)/.local/bin:/opt/homebrew/bin:/usr/bin:/bin"
        do {
            _ = try await ASC.exec("/opt/homebrew/bin/asc", args, timeout: 180, env: ["PATH": path])
            result = out
        } catch {
            let m = error.localizedDescription
            self.error = m.lowercased().contains("koubou") || m.contains("kou")
                ? "Framing needs Koubou. Install it once with: uv tool install koubou==0.20.0 && kou setup-frames" : m
        }
    }
}
