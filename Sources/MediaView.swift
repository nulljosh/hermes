import AppKit
import SwiftUI

// Screenshots and app previews for one version and language, grouped by display size.
struct MediaSets: Decodable {
    struct Entry: Decodable, Identifiable {
        let set: Item
        let screenshots: [Asset]?
        let previews: [Asset]?
        var id: String { self.set.id }
        var assets: [Asset] { screenshots ?? previews ?? [] }
        var size: String {
            let t = self.set.text("screenshotDisplayType") ?? self.set.text("previewType") ?? "?"
            return t.replacingOccurrences(of: "APP_", with: "").replacingOccurrences(of: "_", with: " ")
        }
    }
    let sets: [Entry]
}

struct Asset: Decodable, Identifiable {
    struct Image: Decodable { let templateUrl: String?; let width: Double?; let height: Double? }
    struct Attributes: Decodable { let fileName: String?; let imageAsset: Image?; let previewImage: Image? }
    let id: String
    let attributes: Attributes?

    // Apple's CDN template: {w}x{h}bb.{f}
    func thumb(height: Double) -> URL? {
        guard let img = attributes?.imageAsset ?? attributes?.previewImage, let t = img.templateUrl,
              let w = img.width, let h = img.height, h > 0 else { return nil }
        let width = Int(height * w / h)
        return URL(string: t.replacingOccurrences(of: "{w}", with: "\(width * 2)")
            .replacingOccurrences(of: "{h}", with: "\(Int(height) * 2)").replacingOccurrences(of: "{f}", with: "png"))
    }
}

enum MediaKind: String, CaseIterable, Identifiable {
    case screenshots = "Screenshots", previews = "Previews"
    var id: String { rawValue }
    var command: String { self == .screenshots ? "screenshots" : "video-previews" }
}

struct MediaView: View {
    let app: ASCApp
    @State private var versionID = ""
    @State private var locs: [Item] = []
    @State private var locale = ""
    @State private var error: String?
    @State private var kind = MediaKind.screenshots
    @State private var sets: [MediaSets.Entry]?
    @State private var pending: PendingCommand?
    @State private var uploading = false
    @State private var framing = UserDefaults.standard.bool(forKey: "openFrame")  // QA launch argument: -openFrame YES
    @State private var note: String?

    var locID: String? { locs.first { $0.text("locale") == locale }?.id }

    var body: some View {
        VStack(spacing: 0) {
            VersionLocaleBar(app: app, versionID: $versionID, locs: $locs, locale: $locale, error: $error) {
                Picker("", selection: $kind) { ForEach(MediaKind.allCases) { Text($0.rawValue).tag($0) } }
                    .pickerStyle(.segmented).labelsHidden().fixedSize()
                Button("Download", systemImage: "square.and.arrow.down") { download() }
                    .labelStyle(.iconOnly).help("Download all").disabled(kind == .previews)
                Button("Frame...", systemImage: "iphone") { framing = true }
                Button("Upload", systemImage: "square.and.arrow.up") { uploading = true }
                    .labelStyle(.iconOnly).help("Upload")
            }
            Divider().overlay(Theme.line)
            if let error {
                Text(error).foregroundStyle(Theme.bad).padding().textSelection(.enabled)
                Spacer()
            } else if let sets {
                if sets.isEmpty {
                    Text("No \(kind.rawValue.lowercased()) for this language yet.").foregroundStyle(Theme.muted).frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            ForEach(sets) { s in setRow(s) }
                        }
                        .padding(16)
                    }
                }
            } else {
                ProgressView().frame(maxHeight: .infinity)
            }
        }
        .commands($pending) { await load() }
        .sheet(isPresented: $framing) { FrameView { framing = false }.font(Theme.font(13)) }
        .sheet(isPresented: $uploading) {
            MediaUpload(kind: kind, locID: locID ?? "", sizes: sets?.map { $0.set.text("screenshotDisplayType") ?? $0.set.text("previewType") ?? "" } ?? []) { cmd in
                uploading = false
                if let cmd { pending = cmd }
            }
            .font(Theme.font(13))
        }
        .alert("Upload check", isPresented: Binding(get: { note != nil }, set: { if !$0 { note = nil } })) { Button("OK") {} } message: { Text(note ?? "") }
        .task(id: "\(locID ?? "")-\(kind.rawValue)") { await load() }
    }

    func load() async {
        guard let locID else { return }
        sets = nil; error = nil
        do {
            let data = try await ASC.run([kind.command, "list", "--version-localization", locID])
            sets = try JSONDecoder().decode(MediaSets.self, from: data).sets
        } catch { self.error = error.localizedDescription }
    }

    func setRow(_ s: MediaSets.Entry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(s.size).font(Theme.font(13, .semibold))
                Text("\(s.assets.count) / \(kind == .screenshots ? 10 : 3)").font(Theme.font(11)).foregroundStyle(Theme.muted)
            }
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(s.assets) { a in
                        Thumb(asset: a) { pending = PendingCommand(title: "Delete", args: [kind.command, "delete", "--id", a.id, "--confirm"]) }
                            .contextMenu {
                                if kind == .previews {
                                    ForEach([0, 2, 5, 10, 15], id: \.self) { sec in
                                        Button("Poster Frame at \(sec)s") {
                                            pending = PendingCommand(title: "Set Poster Frame", args: ["video-previews", "set-poster-frame", "--id", a.id, "--time-code", String(format: "00:00:%02d:00", sec)])
                                        }
                                    }
                                }
                            }
                    }
                }
            }
        }
    }

    func download() {
        guard let locID, let dir = pickFolder("Download Here") else { return }
        Task {
            do {
                _ = try await ASC.run(["screenshots", "download", "--version-localization", locID, "--output-dir", dir.path], json: false)
                NSWorkspace.shared.open(dir)
            } catch { self.error = error.localizedDescription }
        }
    }
}

struct Thumb: View {
    let asset: Asset
    let delete: () -> Void
    @State private var hover = false

    var body: some View {
        AsyncImage(url: asset.thumb(height: 220)) { img in img.resizable().scaledToFit() } placeholder: { Theme.surface }
            .frame(height: 220)
            .frame(minWidth: 100)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(alignment: .topTrailing) {
                if hover {
                    Button(action: delete) { Image(systemName: "xmark.circle.fill").font(.title2) }
                        .buttonStyle(.plain).foregroundStyle(Theme.text, Theme.bad).padding(6).help("Delete")
                }
            }
            .onHover { hover = $0 }
            .help(asset.attributes?.fileName ?? "")
    }
}

// Picks a folder and a display size, checks the upload with --dry-run, then hands back the real command to confirm.
struct MediaUpload: View {
    let kind: MediaKind
    let locID: String
    let sizes: [String]
    let done: (PendingCommand?) -> Void
    @State private var device = ""
    @State private var folder: URL?
    @State private var replace = false
    @State private var check: String?

    var body: some View {
        Form {
            TextField("Display size", text: $device, prompt: Text(kind == .screenshots ? "IPHONE_65" : "IPHONE_65"))
            if !sizes.isEmpty { Text("This language already has: " + sizes.map { $0.replacingOccurrences(of: "APP_", with: "") }.joined(separator: ", ")).font(.caption).foregroundStyle(.secondary) }
            HStack {
                Text(folder?.lastPathComponent ?? "No folder")
                Spacer()
                Button("Choose Folder") { folder = pickFolder("Use Folder") }
            }
            Toggle("Replace what is there", isOn: $replace)
            if let check { Text(check).font(.caption).foregroundStyle(.secondary).textSelection(.enabled) }
            HStack {
                Button("Cancel") { done(nil) }
                Spacer()
                Button("Check and Upload") { Task { await run() } }
                    .disabled(device.isEmpty || folder == nil)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .onAppear { device = sizes.first?.replacingOccurrences(of: "APP_", with: "") ?? "" }
    }

    func run() async {
        guard let folder else { return }
        let args = [kind.command, "upload", "--version-localization", locID, "--path", folder.path, "--device-type", device]
            + (replace ? ["--replace", "--confirm"] : [])
        do {
            _ = try await ASC.run(args + ["--dry-run"])
            done(PendingCommand(title: "Upload \(kind.rawValue)", args: args))
        } catch {
            check = error.localizedDescription
        }
    }
}
