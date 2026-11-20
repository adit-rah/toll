import SwiftUI
import TollCore
import TollUI

/// This week: three numbers, then the nights. Before three nights, the slots and one line instead
/// of the chart. The third number is the unlocks Dusk owns; Apple's "screen time after bedtime" will
/// get a row of its own when its report extension exists, never this grid (#44).
struct WeekCard: View {
  let home: HomeSnapshot

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      if home.showsTrends {
        AdaptiveStack(spacing: 12) {
          Stat(
            value: Copy.Home.nightsBlocked(
              home.nightsBlocked, of: max(home.nightsCounted, home.nightsBlocked)),
            label: Copy.Home.nightsBlockedLabel)
          Stat(value: "\(home.timesStopped)", label: Copy.Home.stoppedLabel)
          Stat(value: home.unlockStat.value, label: home.unlockStat.label)
        }
        Text(Copy.Home.byNight)
          .tollType(.microEyebrow, TollColor.label2)
          .padding(.top, 22)
        NightBars(bars: home.bars).padding(.top, 6)
      } else {
        FirstNights(bars: home.bars)
        Text(home.firstWeekLine)
          .tollType(.link, TollColor.label)
          .padding(.top, 16)
        Text(Copy.Home.trendsLater)
          .tollType(TollType(size: 14, lineHeight: 20, weight: .regular, style: .subheadline))
          .foregroundStyle(TollColor.label2)
          .padding(.top, 2)
      }
      if let nights = home.supply.nightsToRefill {
        Text(Copy.Door.refill(after: nights))
          .tollType(.caption, TollColor.label2)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.top, 14)
      }
    }
    .padding(.vertical, TollSpacing.statsCardVertical)
    .padding(.horizontal, TollSpacing.cardPadding)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      TollColor.surface, in: RoundedRectangle(cornerRadius: TollRadius.card, style: .continuous))
  }
}

/// A number and what it counts.
struct Stat: View {
  let value: String
  let label: String

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(value).tollType(.stat, TollColor.label)
      Text(label).tollType(.caption, TollColor.label2).fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }
}

/// Times Sleep stopped you, one bar per night: tallest 64 pt, a 0 as a 3 pt sliver, a night without
/// a block as a dash (named when away or off), nights to come as dashed outlines; the latest night in
/// amber, as the board.
struct NightBars: View {
  let bars: [HomeSnapshot.Bar]

  var body: some View {
    let top = max(1, bars.map(\.count).max() ?? 1)
    HStack(alignment: .bottom, spacing: 8) {
      ForEach(Array(bars.enumerated()), id: \.offset) { _, bar in
        VStack(spacing: 0) {
          value(bar)
          shape(bar, top: top)
          Text(bar.day)
            .tollType(.micro, bar.isLatest ? TollColor.label : TollColor.label2)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(NightSpoken.label(bar))
      }
    }
    .frame(height: 104, alignment: .bottom)
    .tollChartTypeLimit()
  }

  @ViewBuilder private func value(_ bar: HomeSnapshot.Bar) -> some View {
    switch bar.night {
    case .stopped(let count):
      Text("\(count)").tollType(.microNumber, TollColor.label2).padding(.bottom, 4)
    case .away:
      Text(Copy.Home.awayNight).tollType(.micro, TollColor.label3).padding(.bottom, 4)
    case .off, .noScreenTime:
      Text(Copy.Home.offNight).tollType(.micro, TollColor.label3).padding(.bottom, 4)
    case .missed, .noBlock:
      Text(Copy.Home.noBlockNight).tollType(.microNumber, TollColor.label3).padding(.bottom, 4)
    case .ahead:
      EmptyView()
    }
  }

  @ViewBuilder private func shape(_ bar: HomeSnapshot.Bar, top: Int) -> some View {
    let shape = RoundedRectangle(cornerRadius: TollRadius.chartBar, style: .continuous)
    switch bar.night {
    case .stopped(let count):
      shape
        .fill(bar.isLatest ? TollColor.accent : TollColor.bar)
        .frame(height: count == 0 ? 3 : max(4, 64 * CGFloat(count) / CGFloat(top)))
    case .missed, .noBlock, .away, .off, .noScreenTime:
      RoundedRectangle(cornerRadius: 1).fill(TollColor.separator).frame(height: 2)
    case .ahead:
      shape
        .strokeBorder(TollColor.bar, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
        .frame(height: 64)
    }
  }
}

/// What VoiceOver says for a night, in the chart and in the first week's slots (design §4): never
/// the colour or the tick alone.
enum NightSpoken {
  static func label(_ bar: HomeSnapshot.Bar, counts: Bool = true) -> String {
    let state: String =
      switch bar.night {
      case .stopped(let n): counts ? Copy.Home.stoppedSpoken(n) : Copy.Home.blockedSpoken
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

/// The first nights: seven 40 pt slots, a blocked night in amber with a tick, an away or paused one
/// named, the rest dashed.
struct FirstNights: View {
  let bars: [HomeSnapshot.Bar]

  var body: some View {
    HStack(spacing: 8) {
      ForEach(Array(bars.enumerated()), id: \.offset) { _, bar in
        VStack(spacing: 6) {
          slot(bar)
          Text(bar.day)
            .tollType(.micro, bar.night == .ahead ? TollColor.label2 : TollColor.label)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(NightSpoken.label(bar, counts: false))
      }
    }
    .tollChartTypeLimit()
  }

  @ViewBuilder private func slot(_ bar: HomeSnapshot.Bar) -> some View {
    let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
    switch bar.night {
    case .stopped:
      shape.fill(TollColor.accentSoft)
        .overlay(shape.strokeBorder(TollColor.accent, lineWidth: 1))
        .overlay(Image(systemName: "checkmark").font(.system(size: 14, weight: .semibold)))
        .foregroundStyle(TollColor.accent)
        .frame(height: 40)
    case .away, .off, .noScreenTime:
      shape.fill(TollColor.surfaceRaised)
        .overlay(
          Text(bar.night == .away ? Copy.Home.awayNight : Copy.Home.offNight)
            .tollType(.micro, TollColor.label3)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        )
        .frame(height: 40)
    case .missed, .noBlock:
      shape.fill(TollColor.surfaceRaised).frame(height: 40)
    case .ahead:
      shape.strokeBorder(TollColor.bar, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
        .frame(height: 40)
    }
  }
}
