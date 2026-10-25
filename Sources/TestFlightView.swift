import AppKit
import SwiftUI

// TestFlight groups: create, edit, delete, and their testers.
struct TestFlightView: View {
    let app: ASCApp
    @State private var groups: [Item]?
    @State private var error: String?
    @State private var open: Item?
    @State private var editing: Item?
    @State private var creating = false
    @State private var pending: PendingCommand?

    var body: some View {
        Group {
            if let open {
                GroupDetail(app: app, group: open) { self.open = nil }
            } else if let error {
                Text(error).foregroundStyle(Theme.bad).padding().textSelection(.enabled)
            } else if let groups {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        HStack { Spacer(); Button("New Group", systemImage: "plus") { creating = true } }
                            .padding(.horizontal, 16).padding(.vertical, 8)
                        if groups.isEmpty { Text("No TestFlight groups yet.").foregroundStyle(Theme.muted).padding(16) }
                        ForEach(groups) { g in
                            Button { open = g } label: { row(g) }.buttonStyle(.plain)
                        }
                    }
                }
            } else { ProgressView().frame(maxHeight: .infinity) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .commands($pending) { await load() }
        .sheet(isPresented: $creating) { GroupForm(app: app, group: nil) { creating = false; Task { await load() } }.font(Theme.font(13)) }
        .sheet(item: $editing) { g in GroupForm(app: app, group: g) { editing = nil; Task { await load() } }.font(Theme.font(13)) }
        .task { await load() }
    }

    func load() async {
        error = nil
        do { groups = try await ASC.items(["testflight", "groups", "list", "--app", app.id]) } catch { self.error = error.localizedDescription }
    }

    func row(_ g: Item) -> some View {
        HStack(spacing: 8) {
            Image(systemName: g.bool("isInternalGroup") ? "person.2" : "globe").foregroundStyle(Theme.accent).frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(g.text("name") ?? g.id).font(Theme.font(13, .semibold))
                Text([g.bool("isInternalGroup") ? "Internal" : "External", g.bool("publicLinkEnabled") ? "public link on" : nil,
                      g.bool("feedbackEnabled") ? "feedback on" : nil].compactMap { $0 }.joined(separator: " · "))
                    .font(Theme.font(11)).foregroundStyle(Theme.muted)
            }
            Spacer()
            Menu {
                Button("Edit...") { editing = g }
                if let link = g.text("publicLink") { Button("Copy Public Link") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(link, forType: .string) } }
                Divider()
                Button("Delete", role: .destructive) {
                    pending = PendingCommand(title: "Delete \(g.text("name") ?? "Group")", args: ["testflight", "groups", "delete", "--id", g.id, "--confirm"])
                }
            } label: { Image(systemName: "ellipsis.circle") }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
        }
        .padding(.horizontal, 8).padding(.vertical, 10)
        .contentShape(Rectangle())
        .hoverable()
    }
}

struct GroupDetail: View {
    let app: ASCApp
    let group: Item
    let back: () -> Void
    @State private var testers: [Item]?
    @State private var emails = ""
    @State private var pending: PendingCommand?

    var body: some View {
        Form {
            Section {
                Button(action: back) { Label("Groups", systemImage: "chevron.left") }.buttonStyle(.plain).foregroundStyle(Theme.accent)
            }
            Section(group.text("name") ?? "Group") {
                if let testers {
                    if testers.isEmpty { Text("No testers yet.").foregroundStyle(Theme.muted) }
                    ForEach(testers) { t in
                        VStack(alignment: .leading, spacing: 2) {
                            Text([t.text("firstName"), t.text("lastName")].compactMap { $0 }.joined(separator: " ").ifEmpty(t.text("email") ?? t.id))
                            Text([t.text("email"), t.text("state")].compactMap { $0 }.joined(separator: " · ")).font(Theme.font(11)).foregroundStyle(Theme.muted)
                        }
                    }
                } else { ProgressView() }
            }
            Section("Add Testers") {
                TextField("Emails, separated by commas", text: $emails)
                Button("Invite") {
                    pending = PendingCommand(title: "Invite Testers", args: ["testflight", "groups", "add-testers", "--group", group.id, "--email", emails.replacingOccurrences(of: " ", with: "")])
                }
                .disabled(emails.isEmpty)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .commands($pending) { emails = ""; await load() }
        .task { await load() }
    }

    func load() async {
        testers = (try? await ASC.items(["testflight", "testers", "list", "--app", app.id, "--group", group.id])) ?? []
    }
}

struct GroupForm: View {
    let app: ASCApp
    let group: Item?
    let close: () -> Void
    @State private var name = ""
    @State private var internalGroup = false
    @State private var publicLink = false
    @State private var feedback = true
    @State private var pending: PendingCommand?

    var body: some View {
        Form {
            TextField("Name", text: $name)
            if group == nil { Toggle("Internal (App Store Connect users only)", isOn: $internalGroup) }
            if !internalGroup { Toggle("Public link", isOn: $publicLink) }
            Toggle("Tester feedback", isOn: $feedback)
            HStack {
                Button("Cancel", action: close)
                Spacer()
                Button(group == nil ? "Create" : "Save") {
                    var args: [String]
                    if let group {
                        args = ["testflight", "groups", "edit", "--id", group.id, "--name", name]
                    } else {
                        args = ["testflight", "groups", "create", "--app", app.id, "--name", name] + (internalGroup ? ["--internal"] : [])
                    }
                    // boolean flags take an explicit value so turning one off is sent too
                    args += ["--feedback-enabled=\(feedback)"] + (internalGroup ? [] : ["--public-link-enabled=\(publicLink)"])
                    pending = PendingCommand(title: group == nil ? "Create Group" : "Save Group", args: args)
                }
                .disabled(name.isEmpty).keyboardShortcut(.defaultAction)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400)
        .commands($pending) { close() }
        .onAppear {
            name = group?.text("name") ?? ""
            internalGroup = group?.bool("isInternalGroup") ?? false
            publicLink = group?.bool("publicLinkEnabled") ?? false
            feedback = group?.bool("feedbackEnabled") ?? true
        }
    }
}
