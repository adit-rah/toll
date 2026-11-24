import SwiftUI
import TollCore
import TollUI

/// The pill under the bar. A free night is grey on `surface`, the last one amber on its tint (D33);
/// both open the purchase sheet (D75), so both carry a chevron, dim while pressed and say what a tap
/// does. "Away from home" is a label: no capsule, no chevron, no tap.
struct PillView: View {
  let pill: HomeSnapshot.Pill
  let open: () -> Void

  /// The free week as seven segments, the nights already ended filled (#77): night 2 and night 6
  /// look different without the words.
  @ViewBuilder private var segments: some View {
    if let night = pill.night {
      Pips(
        filled: night - 1, total: pill.nights, style: .segments, spoken: pill.text
      )
      .accessibilityHidden(true)
    }
  }

  var body: some View {
    if pill.opensPurchase {
      let last = pill.kind == .lastNight
      Button(action: open) {
        HStack(spacing: 6) {
          segments
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
    } else {
      HStack(spacing: 6) {
        segments
        if pill.kind == .away {
          Image(symbol: .away).unredacted().font(.system(size: 12, weight: .medium))
        }
        Text(pill.text)
      }
      .tollType(TollType(size: 13, lineHeight: 18, weight: .medium, style: .footnote))
      .foregroundStyle(TollColor.label2)
      // No capsule: on Tonight a capsule is something to tap (the free-week pill, Pause), D75.
      .padding(.horizontal, 14)
      .frame(minHeight: 30)
      .accessibilityElement(children: .combine)
    }
  }
}
