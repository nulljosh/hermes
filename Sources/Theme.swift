import SwiftUI

// Tokens mirror brand/tokens.css. One accent, flat surfaces, no gradients or shadows.
enum Theme {
    static let bg = Color(hex: 0x171614)
    static let surface = Color(hex: 0x211F1C)
    static let line = Color(hex: 0x33302B)
    static let text = Color(hex: 0xF3EFE8)
    static let muted = Color(hex: 0x9A948A)
    static let accent = Color(hex: 0xD9703F)
    static let live = Color(hex: 0x4CAF6E)
    static let pending = Color(hex: 0x5B9BD5)
    static let bad = Color(hex: 0xD9534F)
    static let idle = Color(hex: 0x6F6A62)

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
