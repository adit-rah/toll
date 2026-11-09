import SwiftUI
import TollCore
import TollUI

/// The wait overlay over Home and the tabs (G-4, design §3.7). Shown only inside Toll; nothing about the
/// wait appears anywhere else.
struct GateLayer: View {
  let app: AppModel
  @State private var model: GateModel?
  @State private var naming: Tag?

  var body: some View {
    ZStack {
      if let model, model.phase != .hidden, let ref = model.primaryApp {
        WaitOverlay { card(model, ref: ref) }
          .transition(.opacity)
      }
    }
    .animation(Motion.stateChange, value: model?.phase)
    .task(id: app.gate) {
      if model == nil { model = GateModel(app: app) }
      await model?.sync()
    }
    .onChange(of: naming) { _, tag in
      if let tag, let model { Task { await model.name(tag) } }
    }
  }

  @ViewBuilder
  private func card(_ model: GateModel, ref: AppRef) -> some View {
    @Bindable var model = model
    let countdown: WaitCountdown? =
      if case .waiting(let remaining) = model.phase {
        WaitCountdown(
          remaining: remaining, line: model.waitLine ?? "", cancelTitle: Copy.Wait.cancel,
          onCancel: { Task { await model.cancel() } })
      } else { nil }
    let session = SessionChoice(
      question: Copy.SessionPicker.question, options: model.sessionChoices, selection: $model.selectedMinutes,
      note: Copy.SessionPicker.note, onOpen: { Task { await model.open() } })
    let namingSection: WaitNaming? =
      model.untaggedApp != nil && countdown != nil
      ? WaitNaming(question: Copy.Wait.namingQuestion, note: Copy.Wait.namingNote, selection: $naming) : nil
    WaitCard(countdown: countdown, session: session, naming: namingSection) {
      AppLabel(ref).tollText(.title)
    } openLabel: {
      HStack(spacing: 4) {
        Text(Copy.SessionPicker.openVerb)
        AppLabel(ref)
      }
    }
  }
}
