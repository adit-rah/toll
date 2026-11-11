import SwiftUI
import TollCore
import TollUI

/// One card on its canvas. The preview and the exported image are both this view, so what is
/// shared is what was shown (S-2).
struct ShareCardView: View {
  let card: ShareCardSheet.Card
  let format: ShareCardFormat
  let isDark: Bool
  let name: String?
  let range: String
  let link: String
  let model: InsightsModel

  var body: some View {
    ShareCardFrame(
      format: format, colorScheme: isDark ? .dark : .light, displayName: name, dateRange: range, inviteLink: link
    ) {
      ShareCardContent(card: card, format: format, model: model)
    }
  }
}

/// The numeral, one fact line and at most one small chart (design §3.14). The square has a third of
/// the story's room, so it takes a smaller numeral and leaves the metric row out.
struct ShareCardContent: View {
  let card: ShareCardSheet.Card
  let format: ShareCardFormat
  let model: InsightsModel

  private var isCompact: Bool { format == .square }

  var body: some View {
    let me = model.me
    VStack(alignment: .leading, spacing: isCompact ? 10 : 16) {
      switch card {
      case .week:
        big("\(me.thisWeek.passes)")
        fact(Copy.ShareCards.week(me.thisWeek.passes, last: me.lastWeek.passes))
        DayPairBars(pairs: DayPairBars.weekdayPairs(me.days), today: me.today, height: isCompact ? 56 : 88)
        if !isCompact {
          MetricStrip(items: [
            .init(label: Copy.FriendDetail.held, value: me.thisWeek.heldPercent.map(Copy.percent) ?? "—"),
            .init(label: Copy.Insights.cleanDays, value: "\(me.thisWeek.cleanDays)"),
            .init(label: Copy.FriendDetail.waited, value: Copy.minutes(me.thisWeek.waitMinutes)),
          ])
        }
      case .day:
        let passes = me.days.first { $0.day == me.today }?.passes ?? 0
        big("\(passes)")
        fact(Copy.ShareCards.day(passes))
      case .gates:
        big(me.thisWeek.heldPercent.map(Copy.percent) ?? "—")
        fact(Copy.ShareCards.gates(me.thisWeek.heldPercent ?? 0))
        MetricStrip(items: [
          .init(label: Copy.Insights.hits, value: "\(me.thisWeek.hits)"),
          .init(label: Copy.Insights.heldLabel, value: "\(me.thisWeek.held)"),
          .init(label: Copy.Insights.abandoned, value: "\(me.thisWeek.abandoned)"),
        ])
      case .friends:
        let held = model.friends?.friendsHeldPercent ?? 0
        big(Copy.percent(held))
        fact(Copy.ShareCards.friends(held))
      case .school:
        let school = model.school
        big(school?.schoolHeldPercent.map(Copy.percent) ?? "—")
        fact(
          Copy.ShareCards.school(
            school?.school?.name ?? "", schoolPercent: school?.schoolHeldPercent ?? 0,
            mine: school?.myHeldPercent ?? 0))
      case .exam:
        if let caption = model.examCaption { fact(caption) }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func big(_ text: String) -> some View {
    HeroNumber(text, size: isCompact ? 64 : 96)
  }

  private func fact(_ text: String) -> some View {
    Text(text).tollText(.headline).monospacedDigit().fixedSize(horizontal: false, vertical: true)
  }
}
