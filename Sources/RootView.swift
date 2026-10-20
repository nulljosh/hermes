import SwiftUI

struct RootView: View {
    @State private var store = Store()
    @State private var query = ""
    @State private var selected: ASCApp?

    var body: some View {
        HStack(spacing: 0) {
            Sidebar(app: selected)
                .frame(width: 260)
                .layoutPriority(1)
            Rectangle().fill(Theme.line).frame(width: 1)
            Group {
                if let app = selected {
                    DetailView(app: app, store: store) { selected = nil }
                } else {
                    AppList(store: store, query: $query) { selected = $0 }
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity)
            .clipped()
        }
        .background(Theme.bg)
        .foregroundStyle(Theme.text)
        .font(Theme.font(13))
        .preferredColorScheme(.dark)
        .frame(minWidth: 760, minHeight: 480)
        .task {
            await store.load()
            // QA launch argument: -selectApp <app id> opens that app straight away.
            if let id = UserDefaults.standard.string(forKey: "selectApp") { selected = store.apps.first { $0.id == id } }
        }
    }
}

struct Sidebar: View {
    let app: ASCApp?

    var body: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(nsImage: NSApp.applicationIconImage)
                .resizable().scaledToFit().frame(width: 80, height: 80)
            Text(app.map { $0.name } ?? "Welcome to Talaria").font(Theme.font(17, .semibold))
            Text(app == nil ? "Select an app to get started." : app!.bundleId)
                .foregroundStyle(Theme.muted)
            Spacer()
            HStack {
                Link("Send Feedback", destination: URL(string: "mailto:trommatic@icloud.com?subject=Talaria")!)
                    .foregroundStyle(Theme.accent)
                Spacer()
                Text("v" + (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"))
                    .foregroundStyle(Theme.muted)
            }
            .font(Theme.font(11))
        }
        .padding(16)
        .background(Theme.surface)
    }
}

struct AppList: View {
    let store: Store
    @Binding var query: String
    let pick: (ASCApp) -> Void

    var shown: [ASCApp] {
        query.isEmpty ? store.apps : store.apps.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button { Task { await store.load() } } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.plain).foregroundStyle(Theme.muted)
                    .opacity(store.loading ? 0.4 : 1)
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(Theme.muted)
                    TextField("Search Apps...", text: $query).textFieldStyle(.plain)
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Theme.surface, in: Capsule())
            }
            .padding(12)
            Divider().overlay(Theme.line)
            if let e = store.error {
                Text(e).foregroundStyle(Theme.bad).padding().textSelection(.enabled)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(shown) { app in
                            Button { pick(app) } label: { AppRow(app: app, store: store) }
                                .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

struct AppRow: View {
    let app: ASCApp
    let store: Store

    var body: some View {
        HStack(spacing: 12) {
            AppIcon(app: app, url: store.icons[app.id], size: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name).font(Theme.font(14, .semibold))
                ForEach(store.versions[app.id] ?? []) { v in
                    HStack(spacing: 6) {
                        Circle().fill(Theme.stateColor(v.state)).frame(width: 7, height: 7)
                        Text("\(v.version) on \(Theme.platform(v.platform))")
                            .font(Theme.font(11, .medium)).foregroundStyle(Theme.muted)
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 8).padding(.vertical, 8)
        .contentShape(Rectangle())
        .hoverable()
    }
}

struct AppIcon: View {
    let app: ASCApp
    let url: URL?
    let size: CGFloat

    var body: some View {
        AsyncImage(url: url) { img in img.resizable().scaledToFit() } placeholder: {
            Theme.surface.overlay(Text(String(app.name.prefix(1))).font(Theme.font(size * 0.45, .semibold)).foregroundStyle(Theme.accent))
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.225, style: .continuous))
    }
}
