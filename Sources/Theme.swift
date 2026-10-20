import AppKit
import SwiftUI

// Tokens mirror brand/tokens.css. One accent, flat surfaces, no gradients or shadows.
enum Theme {
    // Light and dark, from brand/tokens.css. The window follows the system appearance.
    static let bg = Color(light: 0xFAF8F4, dark: 0x171614)
    static let surface = Color(light: 0xF1EDE6, dark: 0x211F1C)
    static let line = Color(light: 0xE3DDD3, dark: 0x33302B)
    static let text = Color(light: 0x1F1D1A, dark: 0xF3EFE8)
    static let muted = Color(light: 0x6B655C, dark: 0x9A948A)
    static let accent = Color(light: 0x0066C0, dark: 0x3D9BF0)
    static let live = Color(light: 0x2F8A4E, dark: 0x4CAF6E)
    static let pending = Color(light: 0xB07A00, dark: 0xE0A800)
    static let bad = Color(light: 0xC0392B, dark: 0xD9534F)
    static let idle = Color(light: 0x8A847A, dark: 0x6F6A62)

    // Falls back to the system face if the bundled one is missing.
    static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom("Hermes Sans", size: size).weight(weight)
    }

    static func stateColor(_ state: String?) -> Color {
        guard let s = state else { return idle }
        if s.contains("REJECT") || s == "INVALID_BINARY" { return bad }
        if s.hasPrefix("READY_FOR") || s == "ACCEPTED" { return live }
        if s.contains("REVIEW") || s.hasPrefix("PENDING") || s.hasPrefix("PROCESSING") { return pending }
        return idle
    }

    static func platform(_ p: String) -> String {
        ["IOS": "iOS", "MAC_OS": "macOS", "TV_OS": "tvOS", "VISION_OS": "visionOS"][p] ?? p
    }
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(nsColor: NSColor(name: nil) { a in
            let h = a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: CGFloat(h >> 16 & 255) / 255, green: CGFloat(h >> 8 & 255) / 255, blue: CGFloat(h & 255) / 255, alpha: 1)
        })
    }

    init(hex: UInt32) {
        self.init(red: Double(hex >> 16 & 255) / 255, green: Double(hex >> 8 & 255) / 255, blue: Double(hex & 255) / 255)
    }
}

// Row hover: a flat surface fill and a pointing hand, no shadow.
struct Hoverable: ViewModifier {
    @State private var on = false
    func body(content: Content) -> some View {
        content
            .background(on ? Theme.surface : .clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(.horizontal, 8)
            .animation(.easeOut(duration: 0.12), value: on)
            .onHover { h in
                on = h
                if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
    }
}

extension View {
    func hoverable() -> some View { modifier(Hoverable()) }
}
