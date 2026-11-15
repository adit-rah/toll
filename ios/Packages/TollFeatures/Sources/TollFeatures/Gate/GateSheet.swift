import SwiftUI
import TollCore
import TollUI

/// The wait and the session picker, as the body of Home's sheet (G-4, G-6, design §3.7, §3.8).
/// The wait keeps running if the sheet is closed; the bar beneath carries the countdown.
struct GateSheetBody: View {
  @Bindable var gate: GateModel

  var body: some View {
    VStack(spacing: 0) {
      switch gate.phase {
      case .waiting(let until):
        waiting(until)
          .transition(.opacity)
      case .choosing, .hidden:
        choosing
          .transition(.opacity)
      }
    }
    .frame(maxWidth: .infinity)
  }

  private func waiting(_ until: Date) -> some View {
    VStack(spacing: 0) {
      CountdownClock(endsAt: until)
      Text(gate.waitLine ?? "")
        .tollText(.caption)
        .monospacedDigit()
        .multilineTextAlignment(.center)
        .padding(.top, TollSpacing.labelGap)
      if gate.untaggedApp != nil {
        naming
          .padding(.top, TollSpacing.groupGap)
      }
      Text(Copy.Sheet.waitNote)
        .tollText(.caption)
        .multilineTextAlignment(.center)
        .padding(.top, TollSpacing.cardPadding)
        .padding(.horizontal, 12)
    }
  }

  /// First-wait naming (design §3.9): shown while the app has no tag; the chip fills, the others fade.
  private var naming: some View {
    VStack(spacing: 0) {
      Hairline()
      Text(Copy.Wait.namingQuestion)
        .font(TollFont.subheadMedium)
        .foregroundStyle(TollColor.label)
        .accessibilityAddTraits(.isHeader)
        .padding(.top, TollSpacing.cardPadding)
      Text(Copy.Wait.namingNote)
        .tollText(.detail)
        .multilineTextAlignment(.center)
        .padding(.top, 2)
      TagChips(
        selection: Binding(get: { gate.chosenTag }, set: { tag in if let tag { gate.name(tag) } }),
        playsHaptic: false
      )
      .padding(.top, TollSpacing.labelGap)
    }
  }

  private var choosing: some View {
    VStack(spacing: 0) {
      Text(Copy.SessionPicker.question).tollText(.subhead)
      FlowLayout(spacing: 8, lineSpacing: -2) {
        ForEach(gate.sessionChoices, id: \.self) { minutes in
          ChoiceChip(Copy.minutes(minutes), isSelected: gate.selectedMinutes == minutes) {
            gate.selectedMinutes = minutes
          }
        }
      }
      .padding(.top, 7)
      Text(Copy.SessionPicker.note)
        .tollText(.caption)
        .multilineTextAlignment(.center)
        .padding(.top, 3)
    }
  }
}

/// The sheet's bottom edge for the gate: Cancel the wait, or Unblock for N min over Not now.
struct GateSheetActions: View {
  let gate: GateModel
  let close: (@escaping @MainActor () async -> Void) -> Void

  var body: some View {
    switch gate.phase {
    case .waiting:
      QuietButton(Copy.Sheet.cancelWait, tone: .secondary) { close { await gate.cancel() } }
    case .choosing, .hidden:
      VStack(spacing: 4) {
        PrimaryButton(Copy.SessionPicker.unblock(minutes: gate.selectedMinutes)) {
          close { await gate.open() }
        }
        .monospacedDigit()
        QuietButton(Copy.SessionPicker.notNow) { close { await gate.notNow() } }
      }
    }
  }
}
