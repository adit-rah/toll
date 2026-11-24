import SwiftUI
import TollCore
import TollUI

/// The pill under the bar. A free night is grey on `surface`, the last one amber on its tint (D33).
/// It opens the purchase sheet (D75), so it carries a chevron, dims while pressed and says what a tap
/// does. Away from home has no pill: the hero says it (the audit).
struct PillView: View {
  let pill: HomeSnapshot.Pill
  let open: () -> Void

  var body: some View {
    let last = pill.kind == .lastNight
    Button(action: open) {
      HStack(spacing: 6) {
        // The free week as seven segments, the nights already ended filled (#77): night 2 and
        // night 6 look different without the words.
        Pips(filled: pill.night - 1, total: pill.nights, style: .segments, spoken: pill.text)
          .accessibilityHidden(true)
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
      .background(last ? TollColor.accentSoft : TollColor.surface, in: Capsule())
      .frame(minHeight: TollSpacing.minTapTarget)
      .contentShape(Rectangle())
    }
    .buttonStyle(.tollPressable)
    .accessibilityHint(Copy.Home.pillHint)
    .accessibilityIdentifier("tonight.pill")
    .padding(.vertical, -7)
  }
}
