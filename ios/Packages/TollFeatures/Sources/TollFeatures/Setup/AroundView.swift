import SwiftUI
import TollCore
import TollUI

/// The time around your sleep (#144): apps lock a while before sleep and stay locked a while after
/// waking. Both sides are the same recommended start for everyone (only the hours come from Health)
/// and grow weekly toward their targets (D76's rule, both sides). The screen reads at a glance: the
/// night drawn lock → sleep → wake → open, and one row a side. Changing a side is a tap away, in a
/// small sheet; most people just read it and go on. Shared by onboarding and the one-time flow,
/// whose last step it is.
struct AroundStep: View {
  @Bindable var draft: FitDraft
  let step: Int?
  var steps = SetupModel.Step.questions
  var action = Copy.Setup.continue
  let next: () -> Void
  @State private var editing: Gap.Side?

  init(
    draft: FitDraft, step: Int?, steps: Int = SetupModel.Step.questions,
    action: String = Copy.Setup.continue, next: @escaping () -> Void
  ) {
    self.draft = draft
    self.step = step
    self.steps = steps
    self.action = action
    self.next = next
    #if DEBUG
      // A demo opens on a side's sheet (docs/renders.md).
      _editing = State(initialValue: DemoScenario.current?.bufferSheet)
    #endif
  }

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
      Card {
        ForEach(Gap.Side.allCases, id: \.self) { side in
          BufferRow(side: side, detail: Copy.Fit.grows(draft[side].start, to: draft[side].target)) {
            editing = side
          }
        }
      }
      .padding(.top, 20)
      Footnote(Copy.Fit.suggested).padding(.top, TollSpacing.underCard)
    } actions: {
      PrimaryButton(action, action: next)
        .disabled(!draft.isValid)
    }
    .sheet(
      isPresented: Binding(get: { editing != nil }, set: { if !$0 { editing = nil } })
    ) {
      if let editing {
        BufferSheet(draft: draft, side: editing) { self.editing = nil }
      }
    }
  }
}

/// One side as a row: its glyph, its name, what it does tonight and grows to, and a chevron that
/// opens its sheet.
struct BufferRow: View {
  let side: Gap.Side
  let detail: String
  let open: () -> Void

  var body: some View {
    Button(action: open) {
      CardRow(side == .before ? Copy.Fit.before : Copy.Fit.after, detail: detail) {
        IconTile(side == .before ? .beforeBed : .afterWake)
      } trailing: {
        Chevron()
      }
    }
    .buttonStyle(.tollPressable)
    .accessibilityHint(Copy.Fit.changeHint)
  }
}

/// One side's two numbers, tonight's minutes and what it grows to, and None. Changes show at once
/// in the picture behind the sheet; Done closes it.
struct BufferSheet: View {
  @Bindable var draft: FitDraft
  let side: Gap.Side
  let close: () -> Void

  var body: some View {
    let buffer = draft[side]
    let limits = draft.config.limits(side)
    SheetPage(height: 430) {
      SheetTitle(side == .before ? Copy.Fit.before : Copy.Fit.after)
      SheetBody(side == .before ? Copy.Fit.beforeSheet : Copy.Fit.afterSheet)
      VStack(spacing: 0) {
        MinutesRow(
          title: Copy.Fit.tonight, minutes: buffer.start, range: 0...buffer.target, step: 5
        ) { draft.setStart(side, $0) }
        Hairline()
        MinutesRow(
          title: Copy.Fit.growsTo, minutes: buffer.target, range: 0...limits.manualMax,
          step: limits.manualStep
        ) { draft.setTarget(side, $0) }
        Hairline()
        TickRow(title: Copy.Fit.off, chosen: buffer.off) {
          draft.setStart(side, buffer.off ? min(limits.start, buffer.target) : 0)
        }
      }
      .padding(.top, 16)
    } actions: {
      PrimaryButton(Copy.Fit.done, action: close)
    }
  }
}

/// A choice as a row, its tick saying when it's chosen, never colour alone.
struct TickRow: View {
  let title: String
  let chosen: Bool
  let pick: () -> Void

  var body: some View {
    Button(action: pick) {
      HStack(spacing: TollSpacing.rowGap) {
        Text(title).tollType(.rowTitle, TollColor.label)
        Spacer(minLength: 0)
        Image(symbol: .done).unredacted()
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(TollColor.accent)
          .opacity(chosen ? 1 : 0)
          .accessibilityHidden(true)
      }
      .frame(minHeight: 54)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(chosen ? .isSelected : [])
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
