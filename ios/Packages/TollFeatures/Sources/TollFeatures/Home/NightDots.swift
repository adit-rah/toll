import SwiftUI
import TollCore
import TollUI

/// Seven nights as seven dots (D65, #103): filled when the block ran; hollow when it didn't, with
/// the reason's glyph for a night away, after the trial or with Screen Time off; a pinpoint where
/// there was no night; a dashed ring for nights to come. The shape carries it, never the colour
/// alone, and nothing reads as a miss. The latest night's day is in full colour. The free nights
/// after the trial are two weeks, drawn a week to a row (D78).
struct NightDots: View {
  let bars: [HomeSnapshot.Bar]
  /// Tonight's morning: a centred row in the hero, as the pauses' dots are, rather than a card's
  /// full width.
  var compact = false

  var body: some View {
    VStack(spacing: 14) {
      ForEach(Array(stride(from: 0, to: bars.count, by: 7)), id: \.self) { first in
        HStack(spacing: 0) {
          ForEach(first..<min(first + 7, bars.count), id: \.self) { index in
            let bar = bars[index]
            VStack(spacing: compact ? 4 : 6) {
              NightDot(dot: bar.dot, side: compact ? 18 : 24)
              Text(bar.day)
                .tollType(.micro, bar.isLatest ? TollColor.label : TollColor.label2)
            }
            .frame(maxWidth: compact ? nil : .infinity)
            .frame(width: compact ? 34 : nil)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(NightSpoken.label(bar))
          }
        }
      }
    }
    .tollChartTypeLimit()
  }
}

private struct NightDot: View {
  let dot: HomeSnapshot.Bar.Dot
  let side: CGFloat

  var body: some View {
    switch dot {
    case .ran:
      Circle().fill(TollColor.accent).frame(width: side, height: side)
    case .hollow(let mark):
      Circle()
        .strokeBorder(TollColor.label3, lineWidth: 1.5)
        .overlay {
          if let mark {
            Image(symbol: symbol(mark)).unredacted()
              .font(.system(size: side < 24 ? 9 : 11, weight: .semibold))
              .foregroundStyle(TollColor.label2)
          }
        }
        .frame(width: side, height: side)
    case .noNight:
      Circle().fill(TollColor.bar).frame(width: 5, height: 5).frame(
        width: side, height: side)
    case .ahead:
      Circle()
        .strokeBorder(TollColor.bar, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
        .frame(width: side, height: side)
    }
  }

  private func symbol(_ mark: HomeSnapshot.Bar.Mark) -> TollSymbol {
    switch mark {
    case .away: .away
    case .off: .off
    case .noScreenTime: .screenTime
    }
  }
}

/// What VoiceOver says for a night (design §4): never the colour or the shape alone, and no count,
/// so each card keeps one number.
enum NightSpoken {
  static func label(_ bar: HomeSnapshot.Bar) -> String {
    let state: String =
      switch bar.night {
      case .stopped: Copy.Home.blockedSpoken
      case .missed: Copy.Home.missedSpoken
      case .away: Copy.Home.awaySpoken
      case .off: Copy.Home.offNight
      case .noScreenTime: Copy.Home.noScreenTimeSpoken
      case .noBlock: Copy.Home.noBlockSpoken
      case .ahead: Copy.Home.aheadSpoken
      }
    return "\(bar.day), \(state)"
  }
}

/// A number and what it counts.
struct Stat: View {
  let value: String
  let label: String
  var symbol: TollSymbol?

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack(alignment: .firstTextBaseline, spacing: 6) {
        if let symbol {
          Image(symbol: symbol).unredacted()
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(TollColor.label2)
            .accessibilityHidden(true)
        }
        Text(value).tollType(.stat, TollColor.label)
      }
      Text(label).tollType(.caption, TollColor.label2).fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }
}
