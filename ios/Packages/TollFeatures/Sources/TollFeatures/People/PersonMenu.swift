import SwiftUI
import TollCore
import TollData
import TollUI

enum PersonAction { case remove, block, report }

/// Long-press actions on any person (flows §7, §22). The parent confirms through `personActions`.
struct PersonMenu: View {
  let isFriend: Bool
  let choose: (PersonAction) -> Void

  var body: some View {
    if isFriend {
      Button(Copy.FriendDetail.remove, role: .destructive) { choose(.remove) }
    }
    Button(Copy.FriendDetail.block, role: .destructive) { choose(.block) }
    Button(Copy.FriendDetail.report) { choose(.report) }
  }
}

/// Confirmations and the report sheet for Remove, Block and Report, wherever a person appears.
struct PersonActionsModifier: ViewModifier {
  let app: AppModel
  @Binding var pending: (PersonAction, PersonRef)?
  let done: () -> Void
  @State private var reporting: PersonRef?

  private func binding(_ action: PersonAction) -> Binding<Bool> {
    Binding(
      get: { pending?.0 == action && action != .report },
      set: { if !$0 { pending = nil } })
  }

  func body(content: Content) -> some View {
    content
      .confirmationDialog(
        Copy.FriendDetail.removeConfirm(pending?.1.displayName ?? ""), isPresented: binding(.remove),
        titleVisibility: .visible
      ) {
        Button(Copy.FriendDetail.remove, role: .destructive) {
          Haptics.warning()
          run { try await app.deps.network.removeFriend($0.id) }
        }
        Button(Copy.FriendDetail.cancel, role: .cancel) {}
      }
      .confirmationDialog(
        Copy.FriendDetail.blockConfirm(pending?.1.displayName ?? ""), isPresented: binding(.block),
        titleVisibility: .visible
      ) {
        Button(Copy.FriendDetail.block, role: .destructive) {
          Haptics.warning()
          run { try await app.deps.network.block($0.id) }
        }
        Button(Copy.FriendDetail.cancel, role: .cancel) {}
      }
      .onChange(of: pending?.1.id) { _, _ in
        if let (action, person) = pending, action == .report {
          reporting = person
          pending = nil
        }
      }
      .sheet(item: $reporting) { person in ReportSheet(app: app, person: person, done: done) }
  }

  private func run(_ work: @escaping (PersonRef) async throws -> Void) {
    guard let person = pending?.1 else { return }
    pending = nil
    Task {
      try? await work(person)
      _ = try? await app.deps.network.refreshHome()
      done()
    }
  }
}

extension View {
  func personActions(app: AppModel, pending: Binding<(PersonAction, PersonRef)?>, done: @escaping () -> Void)
    -> some View
  {
    modifier(PersonActionsModifier(app: app, pending: pending, done: done))
  }
}

/// Reason list, optional text, Send; then "Also block this person?" (flows §22).
struct ReportSheet: View {
  let app: AppModel
  let person: PersonRef
  let done: () -> Void
  @Environment(\.dismiss) private var dismiss
  @State private var reason: ReportReason = .name
  @State private var text = ""
  @State private var isSending = false
  @State private var sent = false
  @State private var failed = false
  @State private var asksToBlock = false

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Picker(Copy.Report.title, selection: $reason) {
            ForEach(ReportReason.allCases, id: \.self) { Text(Copy.Report.reason($0.rawValue)).tag($0) }
          }
          .pickerStyle(.inline)
          .labelsHidden()
        }
        Section {
          TextField(Copy.Report.details, text: $text, axis: .vertical)
            .lineLimit(3...6)
        } footer: {
          // "Sent" only once the server has it; a failed send says so and leaves Send enabled.
          if sent {
            Text(Copy.Report.thanks)
          } else if failed {
            Text(Copy.Errors.generic)
          }
        }
      }
      .navigationTitle(Copy.Report.title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button(Copy.FriendDetail.cancel) { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button(Copy.Report.send) { Task { await send() } }
            .disabled(sent || isSending)
        }
      }
      .confirmationDialog(Copy.Report.alsoBlock, isPresented: $asksToBlock, titleVisibility: .visible) {
        Button(Copy.FriendDetail.block, role: .destructive) { blockToo() }
        Button(Copy.Report.notNow, role: .cancel) { dismiss() }
      }
    }
  }

  private func send() async {
    isSending = true
    defer { isSending = false }
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    do {
      try await app.deps.network.report(person.id, reason: reason, text: trimmed.isEmpty ? nil : trimmed)
      failed = false
      sent = true
      asksToBlock = true
    } catch {
      failed = true
    }
  }

  private func blockToo() {
    Haptics.warning()
    Task {
      try? await app.deps.network.block(person.id)
      _ = try? await app.deps.network.refreshHome()
      done()
      dismiss()
    }
  }
}
