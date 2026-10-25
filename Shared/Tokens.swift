#if canImport(AppKit)
import AppKit
#else
import UIKit
#endif
import SwiftUI

// Tokens mirror brand/tokens.css. One accent, flat surfaces, no gradients or shadows.
enum Theme {
    // Light and dark, from brand/tokens.css. The window follows the system appearance.
    static let bg = Color(light: 0xFDFDFD, dark: 0x0A0E19)
    static let surface = Color(light: 0xF2F3F7, dark: 0x141A2A)
    static let line = Color(light: 0xDCDDE5, dark: 0x252D44)
    static let text = Color(light: 0x1A1A1A, dark: 0xF2F2F5)
    static let muted = Color(light: 0x5A5C6B, dark: 0xA2A9BC)
    static let accent = Color(light: 0x0847C4, dark: 0x6F9DFF)
    static let band = Color(light: 0x0847C4, dark: 0x0A33B5)
    static let bandArt = Color(light: 0xA9C2F7, dark: 0x7D9DF0)
    static let live = Color(light: 0x2F8A4E, dark: 0x4CAF6E)
    static let pending = Color(light: 0xB07A00, dark: 0xE0A800)
    static let bad = Color(light: 0xC0392B, dark: 0xD9534F)
    static let idle = Color(light: 0x8A8D99, dark: 0x6F7488)

    // Falls back to the system face if the bundled one is missing.
    static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom("Hermes Sans", size: size).weight(weight)
    }

    /// Big titles: the same face, bold. One family everywhere.
    static func display(_ size: CGFloat, medium: Bool = false) -> Font {
        font(size, medium ? .semibold : .bold)
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
        func rgb(_ h: UInt32) -> (CGFloat, CGFloat, CGFloat) { (CGFloat(h >> 16 & 255) / 255, CGFloat(h >> 8 & 255) / 255, CGFloat(h & 255) / 255) }
        #if canImport(AppKit)
        self.init(nsColor: NSColor(name: nil) { a in
            let (r, g, b) = rgb(a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light)
            return NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
        })
        #else
        self.init(uiColor: UIColor { t in
            let (r, g, b) = rgb(t.userInterfaceStyle == .dark ? dark : light)
            return UIColor(red: r, green: g, blue: b, alpha: 1)
        })
        #endif
    }

    init(hex: UInt32) {
        self.init(red: Double(hex >> 16 & 255) / 255, green: Double(hex >> 8 & 255) / 255, blue: Double(hex & 255) / 255)
    }
}

