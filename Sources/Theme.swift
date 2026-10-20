import AppKit
import SwiftUI

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
