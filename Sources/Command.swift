import SwiftUI

// A write to App Store Connect: shown as the exact asc command, confirmed, then run.
struct PendingCommand: Identifiable {
    let id = UUID()
    let title: String
    let args: [String]
    // Optional second step; "{id}" is replaced with data.id from the first step's output.
    var then: [String]? = nil
    var line: String {
        ([args] + (then.map { [$0] } ?? [])).map { "asc " + $0.map { $0.contains(" ") ? "\"\($0)\"" : $0 }.joined(separator: " ") }
            .joined(separator: "\nthen ")
    }
}

struct CommandRunner: ViewModifier {
    @Binding var pending: PendingCommand?
    var done: () async -> Void = {}
    @State private var result: String?
    @State private var failed = false

    func body(content: Content) -> some View {
        content
            .confirmationDialog(pending?.title ?? "", isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
                                titleVisibility: .visible, presenting: pending) { cmd in
                Button(cmd.title) { Task { await run(cmd) } }
                Button("Cancel", role: .cancel) {}
            } message: { cmd in
                Text(cmd.line + (ASC.readOnly ? "\n\nRead-only mode is on: asc will refuse this write." : ""))
            }
            .alert(failed ? "It did not go through" : "Done", isPresented: Binding(get: { result != nil }, set: { if !$0 { result = nil } })) {
                Button("OK") {}
            } message: { Text(result ?? "") }
    }

    func run(_ cmd: PendingCommand) async {
        do {
            let data = try await ASC.run(cmd.args)
            if let then = cmd.then {
                struct R: Decodable { struct D: Decodable { let id: String }; let data: D }
                let id = try JSONDecoder().decode(R.self, from: data).data.id
                _ = try await ASC.run(then.map { $0.replacingOccurrences(of: "{id}", with: id) })
            }
            failed = false; result = cmd.title + " finished."
            await done()
        } catch {
            failed = true; result = error.localizedDescription
        }
    }
}

extension View {
    func commands(_ pending: Binding<PendingCommand?>, done: @escaping () async -> Void = {}) -> some View {
        modifier(CommandRunner(pending: pending, done: done))
    }
}
