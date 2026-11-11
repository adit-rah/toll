import SwiftUI
import TollCore
import TollData
import TollUI

/// I-10…I-14. Names appear only where friends already see each other's numbers (I-11).
struct FriendsInsightsCards: View {
  let model: InsightsModel
  let data: FriendsInsights

  var body: some View {
    if let distribution = data.distribution {
      let under = distribution.bins.first { $0.includesMe }?.to ?? 0
      let count = data.people.filter { !$0.isMe && $0.passes < under }.count
      ChartCard(
        title: Copy.Insights.distribution,
        caption: Copy.Insights.friendsUnder(count, of: data.people.count - 1, under: under)
      ) {
        BinBars(bars: distribution.bins.map { Self.bar($0) }, title: Copy.Insights.distribution)
      }
    }
    ChartCard(title: Copy.Insights.heldByFriend, caption: data.friendsHeldPercent.map(Copy.Home.friendsHeld)) {
      ValueBars(rows: heldRows, title: Copy.Insights.heldByFriend)
    }
    ChartCard(title: Copy.Insights.whenFriendsReach, caption: peakCaption) {
      HourBars(
        values: data.friendsByHour.map(Double.init), overlay: data.myByHour.map(Double.init),
        lateStart: model.app.config.insights.lateStart, resetHour: model.app.config.gate.dayResetHour,
        title: Copy.Insights.whenFriendsReach)
    }
    let weekly = data.weekly.compactMap { row in row.heldPercent.map { (week: row.week, percent: $0) } }
    // One week is a dot, not a trend.
    if weekly.count >= 2 {
      ChartCard(title: Copy.Insights.weekOnWeek, caption: changeCaption) {
        PercentLines(
          weeks: data.weekly.map(\.week),
          series: [.init(id: Copy.Insights.friends, points: weekly, isMine: true)],
          title: Copy.Insights.weekOnWeek)
      }
    }
    if let same = data.sameAppSameHour {
      Text(Copy.Insights.sameApp(same.count, app: Copy.Tags.display(same.tag), after: model.lateStartLabel))
        .tollText(.subhead)
        .monospacedDigit()
        .fixedSize(horizontal: false, vertical: true)
        .tollCard()
    }
  }

  static func bar(_ bin: Bin) -> BinBars.Bar {
    BinBars.Bar(id: ChartLabels.bin(from: bin.from, to: bin.to), count: bin.count, mine: bin.includesMe)
  }

  /// Highest held % first (I-11); someone with no gates this week has no percentage and goes last.
  private var heldRows: [ValueBars.Row] {
    data.people.enumerated()
      .sorted { ($0.element.heldPercent ?? -1, $1.offset) > ($1.element.heldPercent ?? -1, $0.offset) }
      .map { index, person in
        ValueBars.Row(
          id: person.user?.id ?? "me-\(index)", name: person.isMe ? Copy.Insights.me : person.user?.displayName ?? "",
          fraction: Double(person.heldPercent ?? 0) / 100, value: person.heldPercent.map(Copy.percent) ?? "—",
          isMine: person.isMe)
      }
  }

  private var peakCaption: String? {
    guard data.friendsByHour.reduce(0, +) >= model.minN,
      let peak = data.friendsByHour.indices.max(by: { data.friendsByHour[$0] < data.friendsByHour[$1] })
    else { return nil }
    return Copy.Insights.peakHour(ChartLabels.hour(peak))
  }

  private var changeCaption: String? {
    let held = data.weekly.compactMap(\.heldPercent)
    guard held.count >= 2, let last = held.last else { return nil }
    return Copy.Insights.friendsChange(last - held[held.count - 2])
  }
}
