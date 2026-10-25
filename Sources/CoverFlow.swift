import SwiftUI

// Cover Flow (7.1): the fleet as the iPod and iTunes showed albums. Icons tilt away on either side of the centre one,
// each over its reflection, and the centred app's versions sit underneath. Click the centre icon to open it.
struct CoverFlow: View {
    let apps: [ASCApp]
    let store: Store
    let pick: (ASCApp) -> Void
    @State private var centred: ASCApp.ID?

    var current: ASCApp? { apps.first { $0.id == centred } ?? apps.first }

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: -40) {
                    ForEach(apps) { app in
                        cover(app)
                            .scrollTransition(.interactive, axis: .horizontal) { view, phase in
                                view.rotation3DEffect(.degrees(phase.value * -55), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
                                    .scaleEffect(phase.isIdentity ? 1 : 0.8)
                            }
                            .zIndex(app.id == current?.id ? 1 : 0)
                            .onTapGesture { tap(app) }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $centred, anchor: .center)
            .contentMargins(.horizontal, 300, for: .scrollContent)
            .frame(height: 300)

            if let app = current {
                VStack(spacing: 6) {
                    Text(app.name).font(Theme.font(17, .semibold))
                    ForEach(store.versions[app.id] ?? []) { v in
                        HStack(spacing: 6) {
                            Circle().fill(Theme.stateColor(v.state)).frame(width: 7, height: 7)
                            Text("\(Theme.platform(v.platform)) \(v.version), \(Watch.words(v.state))").font(Theme.font(12)).foregroundStyle(Theme.muted)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The centre icon opens its app; any other icon slides to the centre first.
    func tap(_ app: ASCApp) {
        if app.id == current?.id { pick(app) } else { withAnimation { centred = app.id } }
    }

    /// The icon over its reflection. The reflection is a flat, faded copy: no gradient, per the house design rules.
    func cover(_ app: ASCApp) -> some View {
        VStack(spacing: 4) {
            AppIcon(app: app, url: store.icons[app.id], size: 180)
            AppIcon(app: app, url: store.icons[app.id], size: 180)
                .scaleEffect(x: 1, y: -1)
                .opacity(0.18)
                .frame(height: 70, alignment: .top)
                .clipped()
        }
        .frame(width: 180)
        .id(app.id)
    }
}
