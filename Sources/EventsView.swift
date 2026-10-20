import SwiftUI

// In-app events: list with state, create, edit the text per language, submit for review, delete.
struct EventsView: View {
    let app: ASCApp
    @State private var events: [Item]?
    @State private var error: String?
    @State private var open: Item?
    @State private var creating = false
    @State private var pending: PendingCommand?

    var body: some View {
        Group {
            if let open {
                EventDetail(app: app, event: open) { self.open = nil; Task { await load() } }
            } else if let error {
                Text(error).foregroundStyle(Theme.bad).padding().textSelection(.enabled)
            } else if let events {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        HStack { Spacer(); Button("New Event", systemImage: "plus") { creating = true } }
                            .padding(.horizontal, 16).padding(.vertical, 8)
                        if events.isEmpty { Text("No in-app events yet.").foregroundStyle(Theme.muted).padding(16) }
                        ForEach(events) { e in Button { open = e } label: { row(e) }.buttonStyle(.plain) }
                    }
                }
            } else { ProgressView().frame(maxHeight: .infinity) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .commands($pending) { await load() }
        .sheet(isPresented: $creating) { NewEvent(app: app) { cmd in creating = false; if let cmd { pending = cmd } } }
        .task { await load() }
    }

    func load() async {
        error = nil
        do { events = try await ASC.items(["app-events", "list", "--app", app.id]) } catch { self.error = error.localizedDescription }
    }

    func row(_ e: Item) -> some View {
        let state = e.text("eventState")
        return HStack(spacing: 8) {
            Circle().fill(Theme.stateColor(state == "PUBLISHED" || state == "APPROVED" ? "READY_FOR_DISTRIBUTION" : state)).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(e.text("referenceName") ?? e.id).font(Theme.font(13, .semibold))
                Text([e.text("badge")?.replacingOccurrences(of: "_", with: " "), state, e.text("priority")].compactMap { $0 }.joined(separator: " · "))
                    .font(Theme.font(11)).foregroundStyle(Theme.muted)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, 8).padding(.vertical, 10)
        .contentShape(Rectangle())
        .hoverable()
    }
}

struct EventDetail: View {
    let app: ASCApp
    let event: Item
    let back: () -> Void
    @State private var locs: [Item] = []
    @State private var pending: PendingCommand?
    @State private var newLocale = ""

    var body: some View {
        Form {
            Section {
                HStack {
                    Button(action: back) { Label("Events", systemImage: "chevron.left") }.buttonStyle(.plain).foregroundStyle(Theme.accent)
                    Spacer()
                    Text(event.text("eventState") ?? "").foregroundStyle(Theme.muted)
                }
            }
            ForEach(locs) { l in EventText(loc: l, pending: $pending) }
            Section("Add a Language") {
                HStack {
                    TextField("Locale", text: $newLocale, prompt: Text("fr-FR"))
                    Button("Add") {
                        pending = PendingCommand(title: "Add Language", args: ["app-events", "localizations", "create", "--event-id", event.id, "--locale", newLocale])
                    }
                    .disabled(newLocale.isEmpty)
                }
            }
            Section("Review") {
                Button("Submit Event for Review") {
                    pending = PendingCommand(title: "Submit Event", args: ["app-events", "submit", "--app", app.id, "--event-id", event.id, "--confirm"])
                }
                .disabled(!["DRAFT", "READY_FOR_REVIEW", "REJECTED"].contains(event.text("eventState") ?? ""))
                Button("Delete Event", role: .destructive) {
                    pending = PendingCommand(title: "Delete Event", args: ["app-events", "delete", "--event-id", event.id, "--confirm"])
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .commands($pending) { newLocale = ""; await load() }
        .task { await load() }
    }

    func load() async {
        locs = (try? await ASC.items(["app-events", "localizations", "list", "--event-id", event.id])) ?? []
    }
}

struct EventText: View {
    let loc: Item
    @Binding var pending: PendingCommand?
    @State private var name = ""
    @State private var short = ""
    @State private var long = ""

    var body: some View {
        Section(Locale.current.localizedString(forIdentifier: loc.text("locale") ?? "") ?? loc.text("locale") ?? "Language") {
            limited("Name", $name, 30)
            limited("Short description", $short, 50)
            limited("Long description", $long, 120, lines: 3)
            Button("Save") {
                pending = PendingCommand(title: "Save Event Text", args: ["app-events", "localizations", "update", "--localization-id", loc.id,
                                                                          "--name", name, "--short-description", short, "--long-description", long])
            }
        }
        .onAppear { name = loc.text("name") ?? ""; short = loc.text("shortDescription") ?? ""; long = loc.text("longDescription") ?? "" }
    }

    func limited(_ title: String, _ text: Binding<String>, _ limit: Int, lines: Int = 1) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text("\(text.wrappedValue.count) / \(limit)").font(Theme.font(10, .medium))
                    .foregroundStyle(text.wrappedValue.count > limit ? Theme.bad : Theme.muted)
            }
            TextField(title, text: text, axis: .vertical).labelsHidden().lineLimit(lines...max(lines, 6))
        }
    }
}

struct NewEvent: View {
    let app: ASCApp
    let done: (PendingCommand?) -> Void
    @State private var name = ""
    @State private var type = "MAJOR_UPDATE"
    @State private var purpose = "APPROPRIATE_FOR_ALL_USERS"
    @State private var priority = "NORMAL"
    @State private var start = Date().addingTimeInterval(7 * 86400)
    @State private var end = Date().addingTimeInterval(14 * 86400)
    @State private var deepLink = ""

    static let types = ["LIVE_EVENT", "PREMIERE", "CHALLENGE", "COMPETITION", "NEW_SEASON", "MAJOR_UPDATE", "SPECIAL_EVENT"]
    static let purposes = ["APPROPRIATE_FOR_ALL_USERS", "ATTRACT_NEW_USERS", "KEEP_ACTIVE_USERS_INFORMED", "BRING_BACK_LAPSED_USERS"]

    var body: some View {
        Form {
            TextField("Reference name", text: $name)
            Picker("Badge", selection: $type) { ForEach(Self.types, id: \.self) { Text($0.replacingOccurrences(of: "_", with: " ").capitalized).tag($0) } }
            Picker("Purpose", selection: $purpose) { ForEach(Self.purposes, id: \.self) { Text($0.replacingOccurrences(of: "_", with: " ").capitalized).tag($0) } }
            Picker("Priority", selection: $priority) { Text("Normal").tag("NORMAL"); Text("High").tag("HIGH") }
            DatePicker("Starts", selection: $start)
            DatePicker("Ends", selection: $end, in: start...)
            TextField("Deep link (optional)", text: $deepLink)
            HStack {
                Button("Cancel") { done(nil) }
                Spacer()
                Button("Create") {
                    let iso = ISO8601DateFormatter()
                    var args = ["app-events", "create", "--app", app.id, "--name", name, "--event-type", type, "--purpose", purpose,
                                "--priority", priority, "--start", iso.string(from: start), "--end", iso.string(from: end),
                                "--publish-start", iso.string(from: start), "--primary-locale", "en-US",
                                "--purchase-requirement", "NO_COST_ASSOCIATED"]
                    if !deepLink.isEmpty { args += ["--deep-link", deepLink] }
                    done(PendingCommand(title: "Create Event", args: args))
                }
                .disabled(name.isEmpty).keyboardShortcut(.defaultAction)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
    }
}
