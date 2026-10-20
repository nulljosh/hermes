import SwiftUI

let glyphNames = ["wing", "caduceus", "helmet", "sandal", "letter", "purse"]

/// Places a view on a circle. Angle and radius animate as numbers, so the view travels along the arc
/// instead of cutting straight across the middle.
struct Orbit: GeometryEffect {
    var angle: Double
    var radius: Double
    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(angle, radius) }
        set { angle = newValue.first; radius = newValue.second }
    }
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: cos(angle) * radius, y: sin(angle) * radius))
    }
}

/// Launch: the wing flips in, Hermes' six things burst out of it and orbit, the name drops in letter by letter,
/// then everything is pulled back into the wing and lifts away.
struct SplashView: View {
    var done: () -> Void
    @Environment(\.accessibilityReduceMotion) private var still
    @State private var flip = 0.0
    @State private var burst = false
    @State private var spin = 0.0
    @State private var letters = 0
    @State private var gather = false
    @State private var leave = false

    var body: some View {
        ZStack {
            Color("LaunchBackground").ignoresSafeArea()
            ZStack {
                ForEach(glyphNames.indices, id: \.self) { i in
                    let a = Double(i) / Double(glyphNames.count) * 2 * .pi + spin
                    let r: Double = burst && !gather ? 132 : 0
                    Image("glyph-\(glyphNames[i])").resizable().scaledToFit()
                        .frame(width: 52, height: 52)
                        .foregroundStyle(.white.opacity(0.92))
                        .rotationEffect(.radians(-spin * 2 + Double(i)))
                        .scaleEffect(burst && !gather ? 1 : 0.1)
                        .modifier(Orbit(angle: a, radius: r))
                        .opacity(burst && !gather ? 1 : 0)
                        .animation(.spring(response: 0.55, dampingFraction: 0.62).delay(gather ? Double(i) * 0.03 : Double(i) * 0.06), value: burst)
                        .animation(.easeIn(duration: 0.3).delay(Double(i) * 0.03), value: gather)
                }
                Image("LaunchMark").resizable().scaledToFit()
                    .frame(width: 100, height: 100)
                    .rotation3DEffect(.degrees(flip), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
                    .scaleEffect(gather ? 1.25 : 1)
                HStack(spacing: 10) {
                    ForEach(Array("HERMES".enumerated()), id: \.offset) { i, ch in
                        Text(String(ch)).font(Theme.display(48))
                            .foregroundStyle(.white)
                            .opacity(i < letters ? 1 : 0)
                            .offset(y: i < letters ? 0 : -28)
                            .rotationEffect(.degrees(i < letters ? 0 : -18))
                            .animation(.spring(response: 0.4, dampingFraction: 0.55), value: letters)
                    }
                }
                .offset(y: 230)
            }
            .scaleEffect(leave ? 1.7 : 1)
            .opacity(leave ? 0 : 1)
        }
        .task {
            if still { try? await Task.sleep(for: .milliseconds(400)); done(); return }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { flip = 360 }
            try? await Task.sleep(for: .milliseconds(250))
            burst = true
            withAnimation(.easeInOut(duration: 2.0)) { spin = .pi * 0.9 }
            try? await Task.sleep(for: .milliseconds(350))
            for i in 1...6 { letters = i; try? await Task.sleep(for: .milliseconds(70)) }
            try? await Task.sleep(for: .milliseconds(800))
            gather = true
            try? await Task.sleep(for: .milliseconds(380))
            withAnimation(.easeIn(duration: 0.3)) { leave = true }
            try? await Task.sleep(for: .milliseconds(300))
            done()
        }
    }
}

/// Four pages. The halftone art drifts against the swipe, and each page's glyph spins in as it arrives.
struct OnboardingView: View {
    var finish: () -> Void
    @State private var page: Int? = {
        #if DEBUG
        return Int(ProcessInfo.processInfo.environment["HERMES_PAGE"] ?? "") ?? 0
        #else
        return 0
        #endif
    }()

    struct Page { let art: String, glyph: String, title: String, body: String }
    let pages = [
        Page(art: "art-prax", glyph: "wing", title: "HERMES", body: "App Store Connect, on your iPhone."),
        Page(art: "art-goltzius", glyph: "caduceus", title: "EVERY APP", body: "Every version, build and review on your account, in one list."),
        Page(art: "art-carceri8", glyph: "letter", title: "READ ONLY", body: "Hermes looks and never touches. Nothing changes at Apple."),
        Page(art: "art-ludovisi", glyph: "purse", title: "YOUR KEY", body: "Your API key stays in your Keychain. No server, no account."),
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            Color("LaunchBackground").ignoresSafeArea()
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(pages.indices, id: \.self) { i in
                        pageView(pages[i]).containerRelativeFrame(.horizontal).id(i)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .scrollPosition(id: $page)
            .ignoresSafeArea()

            VStack(spacing: 20) {
                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { i in
                        Capsule().fill(.white.opacity(i == (page ?? 0) ? 1 : 0.35))
                            .frame(width: i == (page ?? 0) ? 22 : 8, height: 8)
                    }
                }
                .animation(.spring(response: 0.35), value: page)
                Button {
                    if (page ?? 0) < pages.count - 1 { withAnimation(.spring) { page = (page ?? 0) + 1 } } else { finish() }
                } label: {
                    Text((page ?? 0) < pages.count - 1 ? "NEXT" : "CONNECT YOUR KEY")
                        .font(Theme.display(17, medium: true)).tracking(1.5)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(.white, in: RoundedRectangle(cornerRadius: 4))
                        .foregroundStyle(Color("LaunchBackground"))
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 24)
        }
        .overlay(alignment: .topTrailing) {
            Button("Skip", action: finish).font(Theme.font(15, .semibold)).foregroundStyle(.white.opacity(0.8)).padding(20)
        }
    }

    private func pageView(_ p: Page) -> some View {
        VStack(spacing: 0) {
            Image(p.art).resizable().scaledToFill()
                .foregroundStyle(Theme.bandArt)
                .frame(maxWidth: .infinity).frame(height: 440)
                .clipped()
                .scrollTransition(axis: .horizontal) { c, phase in
                    c.offset(x: phase.value * -140).scaleEffect(1 + abs(phase.value) * 0.15)
                }
            VStack(spacing: 14) {
                Image("glyph-\(p.glyph)").resizable().scaledToFit().frame(width: 48, height: 48)
                    .foregroundStyle(.white)
                    .scrollTransition(axis: .horizontal) { c, phase in
                        c.rotationEffect(.degrees(phase.value * 180)).scaleEffect(1 - abs(phase.value) * 0.6).opacity(1 - abs(phase.value))
                    }
                Text(p.title).font(Theme.display(64)).foregroundStyle(.white)
                    .scrollTransition(axis: .horizontal) { c, phase in c.offset(x: phase.value * 90).opacity(1 - abs(phase.value) * 0.8) }
                Text(p.body).font(Theme.font(17)).foregroundStyle(.white.opacity(0.85)).multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
                    .scrollTransition(axis: .horizontal) { c, phase in c.offset(x: phase.value * 40).opacity(1 - abs(phase.value)) }
            }
            .padding(.top, -40)
            Spacer()
        }
    }
}
