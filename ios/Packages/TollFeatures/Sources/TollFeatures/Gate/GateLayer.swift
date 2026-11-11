import SwiftUI
import TollCore
import TollUI

/// The wait overlay over Home and the tabs (G-4, design §3.7). Shown only inside Toll; nothing about the
/// wait appears anywhere else.
struct GateLayer: View {
  let app: AppModel
  @State private var model: GateModel?

  var body: some View {
    WaitOverlay(isPresented: isShown) {
      if let model, let ref = model.primaryApp {
        GateCard(model: model, ref: ref)
      }
    }
    .task(id: app.gate) {
      if model == nil { model = GateModel(app: app) }
      await model?.sync()
    }
  }

  private var isShown: Bool {
    guard let model else { return false }
    return model.phase != .hidden && model.primaryApp != nil
  }
}

/// Its own view so that the card, not the whole layer, is what the model's changes redraw. The
/// countdown is not one of them: the card's clock ticks by itself.
private struct GateCard: View {
  @Bindable var model: GateModel
  let ref: AppRef

  var body: some View {
    WaitCard(countdown: countdown, session: session, naming: naming) {
      AppLabel(ref)
    } openLabel: {
      HStack(spacing: 4) {
        Text(Copy.SessionPicker.openVerb)
        AppLabel(ref)
      }
    }
  }

  private var countdown: WaitCountdown? {
    let gate = self.model
    guard case .waiting(let endsAt) = gate.phase else { return nil }
    return WaitCountdown(
      endsAt: endsAt, line: gate.waitLine ?? "", cancelTitle: Copy.Wait.cancel,
      onCancel: { Task { await gate.cancel() } })
  }

  private var session: SessionChoice {
    let gate = self.model
    return SessionChoice(
      question: Copy.SessionPicker.question, options: gate.sessionChoices, selection: $model.selectedMinutes,
      note: Copy.SessionPicker.note, onOpen: { Task { await gate.open() } },
      onNotNow: { Task { await gate.notNow() } })
  }

  /// Offered only while the wait runs. It stays up after a tag is chosen (`untaggedApp` is kept) so
  /// the card can fill the chip and close the section itself.
  private var naming: WaitNaming? {
    let gate = self.model
    guard gate.untaggedApp != nil, case .waiting = gate.phase else { return nil }
    return WaitNaming(
      question: Copy.Wait.namingQuestion, note: Copy.Wait.namingNote,
      selection: Binding(get: { gate.chosenTag }, set: { tag in if let tag { gate.name(tag) } }))
  }
}
