import SwiftUI
import TollCore
import TollUI

/// The pill in the bar (under it at accessibility sizes). A free night is grey on `surface`, the last one amber on its tint (D33).
/// It opens the purchase sheet (D75), so it carries a chevron, dims while pressed and says what a tap
/// does. Away from home has no pill: the hero says it (the audit).
struct PillView: View {
  let pill: HomeSnapshot.Pill
  /// Off only where the bar is too narrow for both: the words still say which night.
  var segments = true
  let open: () -> Void

  var body: some View {
    let last = pill.kind == .lastNight
    Button(action: open) {
      HStack(spacing: 6) {
        // The free nights as segments, the ones already ended filled and tonight's ringed (#77,
        // the audit): night 2 and night 9 look different without the words.
        if segments {
          FreeNights(
            used: pill.night - 1, total: pill.nights, tonight: pill.night - 1, spoken: pill.text
          )
          .accessibilityHidden(true)
        }
        Text(pill.text)
        Image(symbol: .forward).unredacted().font(.system(size: 10, weight: .bold))
          .accessibilityHidden(true)
      }
      .tollType(
        last ? .trailing : TollType(size: 13, lineHeight: 18, weight: .medium, style: .footnote),
        last ? TollColor.accent : TollColor.label2
      )
      .padding(.leading, 14)
      .padding(.trailing, 12)
      .frame(minHeight: 30)
      .tollSurface(Capsule(), fill: last ? TollColor.accentSoft : TollColor.surface)
      .frame(minHeight: TollSpacing.minTapTarget)
      .contentShape(Rectangle())
    }
    .buttonStyle(.tollPressable)
    .accessibilityHint(Copy.Home.pillHint)
    .accessibilityIdentifier("tonight.pill")
    .padding(.vertical, -7)
  }
}

/// The free nights as segments, a week to a row (D59, D78): two rows of seven read as two weeks
/// without words, and fit the pill and Welcome's card where fourteen in a line would not.
struct FreeNights: View {
  let used: Int
  let total: Int
  var tonight: Int?
  let spoken: String

  var body: some View {
    Pips(
      filled: used, total: total, style: .segments, spoken: spoken, perRow: 7, current: tonight)
  }
}
