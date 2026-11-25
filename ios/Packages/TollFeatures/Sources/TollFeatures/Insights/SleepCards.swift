import SwiftUI
import TollCore
import TollUI

/// This week as seven dots; on a new week, last week in one line above seven empty ones (#103).
struct WeekDotsCard: View {
  let sleep: YourSleep

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      if let lastWeek = sleep.lastWeek {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Image(symbol: .sleep).unredacted()
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(TollColor.label2)
            .accessibilityHidden(true)
          Text(lastWeek)
            .tollType(.rowTitle, TollColor.label)
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
      }
      NightDots(bars: sleep.dots)
    }
    .padding(.vertical, TollSpacing.statsCardVertical)
    .padding(.horizontal, TollSpacing.cardPadding)
    .frame(maxWidth: .infinity, alignment: .leading)
    .tollSurface()
  }
}

/// A personal best, only when it's true and better than the person's own past (D65): a fact and
/// what it's measured against, never praise.
struct BestCard: View {
  let best: YourSleep.Best

  var body: some View {
    HStack(spacing: 14) {
      IconTile(.best, size: .large)
      RowText(title: best.title, detail: best.detail)
      Spacer(minLength: 0)
    }
    .padding(TollSpacing.cardPadding)
    .tollSurface()
    .accessibilityElement(children: .combine)
  }
}
