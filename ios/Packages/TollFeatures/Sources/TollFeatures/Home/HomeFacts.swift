@preconcurrency import DeviceActivity
import SwiftUI
import TollCore
import TollScreenTime
import TollUI

/// The three facts under Home's hero (design §4.1): screen time on blocked apps, this week against
/// last, and times blocked today. Side by side; stacked at accessibility sizes.
struct HomeFacts: View {
  let you: HomeModel.You
  let blockedApps: [AppRef]
  let today: DateInterval
  @Environment(\.dynamicTypeSize) private var typeSize

  private static let maxWidth: CGFloat = 330

  var body: some View {
    if typeSize.isAccessibilitySize {
      VStack(spacing: TollSpacing.cardPadding) { columns }
    } else {
      HStack(alignment: .top, spacing: 0) { columns }
        .frame(maxWidth: Self.maxWidth)
    }
  }

  @ViewBuilder
  private var columns: some View {
    FactColumn(Copy.Home.screenTime) {
      ScreenTimeFact(refs: blockedApps, today: today)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(Copy.Home.screenTimeSpoken)
    FactColumn(Copy.Home.thisWeek) {
      HStack(alignment: .firstTextBaseline, spacing: 6) {
        Text("\(you.thisWeek)")
        Text(Copy.Home.lastWeek(this: you.thisWeek, last: you.lastWeek))
          .font(TollFont.captionNumber)
          .foregroundStyle(TollColor.label2)
      }
      .monospacedDigit()
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Copy.Home.thisWeek)
    .accessibilityValue(Copy.Home.thisWeekSpoken(you.thisWeek, last: you.lastWeek))
    FactColumn(Copy.Home.blocked) {
      Text("\(you.blockedToday)").monospacedDigit()
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Copy.Home.blocked)
    .accessibilityValue(Copy.Home.blockedSpoken(you.blockedToday))
  }
}

/// Today's minutes on blocked apps, drawn by the report extension (ledger A126). Toll hands iOS a
/// filter and iOS draws the number; the app never learns it, so it can never be sent anywhere.
struct ScreenTimeFact: View {
  let refs: [AppRef]
  let today: DateInterval
  @ScaledMetric(relativeTo: .body) private var lineHeight: CGFloat = 22

  var body: some View {
    #if DEBUG
      if DemoStandIns.active {
        Text(DemoStandIns.screenTime)
      } else {
        report
      }
    #else
      report
    #endif
  }

  @ViewBuilder
  private var report: some View {
    let tokens = refs.compactMap { AppTokenCache.tokens(for: $0) }
    if tokens.isEmpty {
      Text("—").foregroundStyle(TollColor.label3)
    } else {
      DeviceActivityReport(
        DeviceActivityReport.Context(ReportContext.screenTime),
        filter: DeviceActivityFilter(
          segment: .daily(during: today), users: .all, devices: .init([.iPhone]),
          applications: Set(tokens.flatMap(\.applications)),
          categories: Set(tokens.flatMap(\.categories)),
          webDomains: Set(tokens.flatMap(\.webDomains)))
      )
      .frame(maxWidth: .infinity)
      .frame(height: lineHeight)
    }
  }
}
