import AppKit
import SwiftUI

// Customer reviews: rating summary, filters, reply with a saved signature, and the write-a-review link.
struct ReviewsView: View {
    let app: ASCApp
    @AppStorage("replySignature") private var signature = ""
    @State private var reviews: [Item]?
    @State private var average: Double?
    @State private var count: Int?
    @State private var error: String?
    @State private var filter = "any"
    @State private var stars = 0
    @State private var replying: Item?
    @State private var editingSignature = false

    var link: String { "https://apps.apple.com/app/id\(app.id)?action=write-review" }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                if let average, let count {
                    Label(count == 0 ? "No ratings yet" : String(format: "%.1f from %d ratings (US)", average, count), systemImage: "star.fill")
                        .foregroundStyle(Theme.muted)
                }
                Spacer()
                Picker("", selection: $filter) {
                    Text("All").tag("any"); Text("Unanswered").tag("unresponded"); Text("Answered").tag("responded")
                }
                .pickerStyle(.segmented).labelsHidden().fixedSize()
                Picker("Stars", selection: $stars) {
                    Text("Any").tag(0)
                    ForEach((1...5).reversed(), id: \.self) { Text(String(repeating: "\u{2605}", count: $0)).tag($0) }
                }
                .fixedSize()
                Menu {
                    Button("Copy Review Link") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(link, forType: .string) }
                    Button("Reply Signature...") { editingSignature = true }
                } label: { Image(systemName: "ellipsis.circle") }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            }
            .padding(12)
            Divider().overlay(Theme.line)
            if let error { Text(error).foregroundStyle(Theme.bad).padding().textSelection(.enabled); Spacer() }
            else if let reviews {
                if reviews.isEmpty { Text("No reviews here yet.").foregroundStyle(Theme.muted).frame(maxHeight: .infinity) }
                else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(reviews) { r in row(r) }
                        }
                    }
                }
            } else { ProgressView().frame(maxHeight: .infinity) }
        }
        .sheet(item: $replying) { r in Reply(review: r, signature: signature) { replying = nil; Task { await load() } }.font(Theme.font(13)) }
        .sheet(isPresented: $editingSignature) { SignatureForm(signature: $signature) { editingSignature = false }.font(Theme.font(13)) }
        .task(id: "\(filter)-\(stars)") { await load() }
    }

    func load() async {
        reviews = nil; error = nil
        var args = ["reviews", "list", "--app", app.id, "--sort", "-createdDate", "--limit", "100", "--response-state", filter]
        if stars > 0 { args += ["--stars", "\(stars)"] }
        do { reviews = try await ASC.items(args) } catch { self.error = error.localizedDescription }
        if average == nil, let data = try? await ASC.run(["reviews", "ratings", "--app", app.id]),
           let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            average = o["averageRating"] as? Double ?? 0
            count = o["ratingCount"] as? Int ?? 0
        }
    }

    func row(_ r: Item) -> some View {
        let rating = Int(r.text("rating") ?? "0") ?? 0
        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(String(repeating: "\u{2605}", count: rating) + String(repeating: "\u{2606}", count: 5 - rating)).foregroundStyle(Theme.accent)
                    Text(r.text("title") ?? "").font(Theme.font(13, .semibold))
                }
                Text(r.text("body") ?? "").foregroundStyle(Theme.text).textSelection(.enabled)
                Text([r.text("reviewerNickname"), r.text("territory"), r.text("createdDate").map { String($0.prefix(10)) }]
                    .compactMap { $0 }.joined(separator: " · ")).font(Theme.font(11)).foregroundStyle(Theme.muted)
            }
            Spacer()
            Button("Reply") { replying = r }
        }
        .padding(.horizontal, 8).padding(.vertical, 12)
        .contentShape(Rectangle())
        .hoverable()
    }
}

struct Reply: View {
    let review: Item
    let signature: String
    let close: () -> Void
    @State private var text = ""
    @State private var pending: PendingCommand?

    var full: String { signature.isEmpty ? text : text + "\n\n" + signature }

    var body: some View {
        Form {
            Text(review.text("title") ?? "Review").font(Theme.font(13, .semibold))
            Text(review.text("body") ?? "").foregroundStyle(.secondary)
            TextField("Your reply", text: $text, axis: .vertical).lineLimit(5...12)
            if !signature.isEmpty { Text(signature).font(.caption).foregroundStyle(.secondary) }
            Text("\(full.count) / 5970").font(.caption).foregroundStyle(full.count > 5970 ? Theme.bad : .secondary)
            HStack {
                Button("Cancel", action: close)
                Spacer()
                Button("Send Reply") {
                    pending = PendingCommand(title: "Send Reply", args: ["reviews", "respond", "--review-id", review.id, "--response", full])
                }
                .disabled(text.isEmpty || full.count > 5970).keyboardShortcut(.defaultAction)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .commands($pending) { close() }
    }
}

struct SignatureForm: View {
    @Binding var signature: String
    let close: () -> Void

    var body: some View {
        Form {
            TextField("Signature added to every reply", text: $signature, axis: .vertical).lineLimit(2...4)
            HStack { Spacer(); Button("Done", action: close).keyboardShortcut(.defaultAction) }
        }
        .formStyle(.grouped)
        .frame(width: 400)
    }
}
