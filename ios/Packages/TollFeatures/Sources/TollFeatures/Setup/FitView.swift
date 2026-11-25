import SwiftUI
import TollCore
import TollUI

/// Fit Dusk to your sleep (#144): one line on why, then Apple Health or the person's own hours.
/// Health is asked for here, where it's used, and iOS's sheet asks for sleep alone. Drawn as
/// Health's tile feeding the night's moon, so the choice reads without words.
struct FitView: View {
  let model: SetupModel

  var body: some View {
    FitChoice(
      draft: model.draft, step: SetupModel.Step.fit.number,
      useHealth: { Task { await model.useHealth() } }, setMyself: model.setMyself)
  }
}

/// The step itself, shared with the one-time flow's sheet.
struct FitChoice: View {
  let draft: FitDraft
  let step: Int?
  var steps = SetupModel.Step.questions
  let useHealth: () -> Void
  let setMyself: () -> Void

  var body: some View {
    SetupPage(
      step: step, of: steps, title: Copy.Fit.title, subtitle: Copy.Fit.line, endsWithLink: true
    ) {
      HealthPicture()
        .frame(maxWidth: .infinity)
        .padding(.top, 36)
      Footnote(Copy.Fit.healthWhy, symbol: .privacy)
        .padding(.top, 36)
    } actions: {
      // No spinner while Health answers: nothing loops (design §2.5); the button waits, disabled.
      PrimaryButton(Copy.Fit.useHealth, action: useHealth)
        .disabled(draft.reading)
      QuietButton(Copy.Fit.setMyself, action: setMyself)
        .disabled(draft.reading)
    }
  }
}

/// Health's tile, an arrow, the night's moon: past sleep becomes the night.
private struct HealthPicture: View {
  var body: some View {
    HStack(spacing: 14) {
      tile(.health)
      Image(symbol: .forward).unredacted()
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(TollColor.label3)
      tile(.sleep)
    }
    .accessibilityHidden(true)
  }

  private func tile(_ symbol: TollSymbol) -> some View {
    Image(symbol: symbol).unredacted()
      .font(.system(size: 34, weight: .medium))
      .foregroundStyle(TollColor.accent)
      .frame(width: 80, height: 80)
      .background(TollColor.accentSoft, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
  }
}
