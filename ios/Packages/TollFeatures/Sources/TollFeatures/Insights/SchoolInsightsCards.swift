import SwiftUI
import TollCore
import TollData
import TollUI

/// I-15…I-19. School aggregates only; nobody is ranked.
struct SchoolInsightsCards: View {
  let model: InsightsModel
  let data: SchoolInsights

  var body: some View {
    let name = data.school?.name ?? ""
    if let distribution = data.distribution {
      let mine = distribution.bins.first { $0.includesMe }
      let total = max(1, distribution.bins.reduce(0) { $0 + $1.count })
      ChartCard(
        title: Copy.Insights.distribution,
        caption: mine.map {
          Copy.Insights.schoolBin(from: $0.from, to: $0.to, percent: $0.count * 100 / total, school: name)
        }
      ) {
        BinBars(bars: distribution.bins.map { FriendsInsightsCards.bar($0) }, title: Copy.Insights.distribution)
      }
    }
    ChartCard(title: Copy.Insights.schoolVsYou, caption: Copy.Insights.asOf) {
      HStack(alignment: .top, spacing: TollSpacing.sectionGap) {
        figure(data.schoolHeldPercent, label: name, isMine: false)
        figure(data.myHeldPercent, label: Copy.Insights.me, isMine: true)
      }
      let school = data.weekly.compactMap { row in row.schoolHeldPercent.map { (week: row.week, percent: $0) } }
      let mine = data.weekly.compactMap { row in row.myHeldPercent.map { (week: row.week, percent: $0) } }
      // One week is a dot, not a trend.
      if max(school.count, mine.count) >= 2 {
        PercentLines(
          weeks: data.weekly.map(\.week),
          series: [
            .init(id: Copy.Insights.school, points: school, isMine: false),
            .init(id: Copy.Insights.me, points: mine, isMine: true),
          ],
          title: Copy.Insights.schoolVsYou)
      }
    }
    ChartCard(title: Copy.Insights.schoolByHour) {
      let myTotal = max(1, data.myByHour.reduce(0, +))
      HourBars(
        values: data.byHour, overlay: data.myByHour.map { Double($0) / Double(myTotal) },
        lateStart: model.app.config.insights.lateStart, resetHour: model.app.config.gate.dayResetHour,
        title: Copy.Insights.schoolByHour)
    }
    let segments = shareSegments
    if let most = segments.first {
      ChartCard(title: Copy.Insights.whatSchoolBlocks, caption: Copy.Insights.mostBlocked(most.name, school: name)) {
        ShareBar(segments: segments, title: Copy.Insights.whatSchoolBlocks)
      }
    }
  }

  /// The two numbers the card is about (I-16), yours in the accent like your line beneath them.
  private func figure(_ percent: Int?, label: String, isMine: Bool) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      HeroNumber(percent.map(Copy.percent) ?? "—", size: 34)
        .foregroundStyle(isMine ? TollColor.accent : TollColor.label)
      Text(label).tollText(.caption).lineLimit(2)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(label)
    .accessibilityValue(percent.map(Copy.percent) ?? "")
  }

  private var shareSegments: [ShareBar.Segment] {
    let total = data.tagShare.values.reduce(0, +)
    guard total > 0 else { return [] }
    return data.tagShare
      .sorted { ($0.value, $1.key) > ($1.value, $0.key) }
      .enumerated()
      .map { rank, share in
        ShareBar.Segment(
          id: share.key, name: Copy.Tags.chip(Tag(rawValue: share.key) ?? .other),
          percent: Int((share.value / total * 100).rounded()), rank: rank)
      }
  }
}
