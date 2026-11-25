import SwiftUI
import TollCore
import TollUI

/// The time around your sleep (#144): apps lock a while before sleep and stay locked a while after
/// waking. Both sides start from the same recommended baseline for everyone (only the hours come
/// from Health) and grow weekly toward their targets (D76's rule, both sides); both numbers on each
/// side can change, and the side after down to none. Drawn as lock → sleep → wake → open. Shared
/// by onboarding and the one-time flow, whose last step it is.
struct AroundStep: View {
  @Bindable var draft: FitDraft
  let step: Int?
  var steps = SetupModel.Step.questions
  var action = Copy.Setup.continue
  let next: () -> Void

  var body: some View {
    SetupPage(
      step: step, of: steps, title: Copy.Fit.aroundTitle, subtitle: Copy.Fit.aroundLine
    ) {
      if let picture = NightPicture(
        .everyDay(draft.window), gap: draft.before.start, after: draft.after.start,
        now: Date(), calendar: .current)
      {
        NightPictureView(picture: picture).padding(.top, 24)
      }
      Footnote(Copy.Fit.suggested).padding(.top, 20)
      BufferCard(draft: draft, side: .before).padding(.top, 8)
      BufferCard(draft: draft, side: .after).padding(.top, 12)
      Footnote(Copy.Fit.afterWhy, symbol: .afterWake).padding(.top, TollSpacing.underCard)
      Footnote(Copy.Fit.growsNote).padding(.top, TollSpacing.underCard)
    } actions: {
      PrimaryButton(action, action: next)
        .disabled(!draft.isValid)
    }
  }
}

/// One side: its glyph and what it does tonight and grows to, then the two numbers.
struct BufferCard: View {
  @Bindable var draft: FitDraft
  let side: Gap.Side

  private var buffer: Fit.Buffer { side == .before ? draft.before : draft.after }
  private var limits: Gap.Limits { draft.config.limits(side) }

  var body: some View {
    Card {
      CardRow(
        side == .before ? Copy.Fit.before : Copy.Fit.after,
        detail: Copy.Fit.grows(buffer.start, to: buffer.target)
      ) {
        IconTile(side == .before ? .beforeBed : .afterWake)
      }
      MinutesRow(
        title: Copy.Fit.tonight, minutes: buffer.start, range: 0...buffer.target, step: 5
      ) { draft.setStart(side, $0) }
      MinutesRow(
        title: Copy.Fit.growsTo, minutes: buffer.target, range: 0...limits.manualMax,
        step: limits.manualStep
      ) { draft.setTarget(side, $0) }
    }
    .accessibilityElement(children: .contain)
  }
}

/// A number of minutes with Apple's stepper, its words and value read out together.
struct MinutesRow: View {
  let title: String
  let minutes: Int
  let range: ClosedRange<Int>
  let step: Int
  let set: (Int) -> Void

  var body: some View {
    Stepper(
      value: Binding(get: { minutes }, set: set), in: range, step: step
    ) {
      AdaptiveStack(spacing: 4) {
        Text(title).tollType(.rowTitle, TollColor.label)
        Spacer(minLength: 0)
        Text(Copy.Fit.minutes(minutes))
          .tollType(.rowTitle, TollColor.label2)
          .monospacedDigit()
      }
    }
    .padding(.vertical, 8)
    .frame(minHeight: 54)
    .accessibilityValue(Copy.Fit.minutes(minutes))
    .tollHaptic(.selection, trigger: minutes)
  }
}
