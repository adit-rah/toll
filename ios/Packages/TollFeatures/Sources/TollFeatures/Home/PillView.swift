import SwiftUI
import TollCore
import TollUI

/// The pill under the bar: grey on `surface` for a free night and for "Away from home"; the last
/// free night in amber on its tint, and only that one opens anything (D33).
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
      Button(action: open) {
        HStack(spacing: 6) {
          segments
          Text(pill.text)
          Image(symbol: .forward).unredacted().font(.system(size: 10, weight: .bold))
        }
        .tollType(.trailing, TollColor.accent)
        .padding(.leading, 14)
        .padding(.trailing, 12)
        .frame(minHeight: 30)
        .background(TollColor.accentSoft, in: Capsule())
        .frame(minHeight: TollSpacing.minTapTarget)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
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
      .padding(.horizontal, 14)
      .frame(minHeight: 30)
      .background(TollColor.surface, in: Capsule())
      .accessibilityElement(children: .combine)
    }
  }
}
