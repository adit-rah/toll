import SwiftUI
import TollCore
import TollUI

/// Your sleep, the second tab (D63): the nights so far, this week as dots and a personal best when
/// there is one (#103), then everything from the log on this phone. Being reframed around the user's
/// improvement (#88); Apple's "Screen time after bedtime" card joins it with the report extension
/// (#65).
struct InsightsView: View {
  let log: [TollCore.Transition]
  let sleep: YourSleep
  @State private var range = InsightsSnapshot.Range.month

  var body: some View {
    let insights = InsightsSnapshot(log: log, now: Date(), calendar: .current, range: range)
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        ScreenTitle(Copy.Tabs.sleep, kind: .pushed)
        if let nights = sleep.nights {
          NightsCard(nights: nights).padding(.top, 20)
        }
        SectionHeader(sleep.weekTitle).padding(.top, 28)
        WeekDotsCard(sleep: sleep).padding(.top, TollSpacing.headerToCard)
        if let best = sleep.best {
          BestCard(best: best).padding(.top, 12)
        }
        Picker(Copy.Insights.title, selection: $range) {
          Text(Copy.Insights.week).tag(InsightsSnapshot.Range.week)
          Text(Copy.Insights.month).tag(InsightsSnapshot.Range.month)
          Text(Copy.Insights.all).tag(InsightsSnapshot.Range.all)
        }
        .pickerStyle(.segmented)
        .padding(.top, 28)
        if insights.isEmpty {
          Footnote(Copy.Insights.empty).padding(.top, 20)
        } else {
          // The nights are counted once, at the top; this is the range's one number.
          Stat(value: Copy.Insights.hours(insights.hoursBlocked), label: Copy.Insights.hoursLabel)
            .padding(.top, 20)
          VStack(spacing: 12) {
            WeeksCard(insights: insights)
            HoursCard(insights: insights)
          }
          .padding(.top, 20)
        }
      }
      .tollGutter()
      .padding(.bottom, 32)
    }
    .background(TollColor.bg)
    .animation(Motion.stateChange, value: range)
    .tollPushed(Copy.Tabs.sleep)
  }
}

/// A card with a 15 pt semibold title (the canvas's Insights cards).
private struct InsightCard<Content: View>: View {
  let title: String
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(title).tollType(.link, TollColor.label).accessibilityAddTraits(.isHeader)
      content
    }
    .padding(TollSpacing.cardPadding)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      TollColor.surface, in: RoundedRectangle(cornerRadius: TollRadius.card, style: .continuous))
  }
}

/// Times it stopped you, one bar per week (at most 56 pt), the latest in amber. No change against
/// week 1: a comparison is shown only when it's better (D65), and more or fewer taps is neither.
private struct WeeksCard: View {
  let insights: InsightsSnapshot

  var body: some View {
    InsightCard(title: Copy.Insights.stopped) {
      let top = max(1, insights.weeks.max() ?? 1)
      HStack(alignment: .bottom, spacing: 8) {
        ForEach(Array(insights.weeks.enumerated()), id: \.offset) { index, count in
          let latest = index == insights.weeks.count - 1
          VStack(spacing: 0) {
            Text("\(count)").tollType(.microNumber, TollColor.label2).padding(.bottom, 4)
            RoundedRectangle(cornerRadius: TollRadius.chartBar, style: .continuous)
              .fill(latest ? TollColor.accent : TollColor.bar)
              .frame(height: max(3, 56 * CGFloat(count) / CGFloat(top)))
            Text(Copy.Insights.weekLabel(index + 1))
              .tollType(.micro, latest ? TollColor.label : TollColor.label2)
              .padding(.top, 8)
          }
          .frame(maxWidth: .infinity)
          .accessibilityElement(children: .ignore)
          .accessibilityLabel("\(Copy.Insights.weekLabel(index + 1)), \(count)")
        }
        // Four slots, as the board: a first week's bar keeps a quarter of the width.
        ForEach(0..<max(0, 4 - insights.weeks.count), id: \.self) { _ in
          Color.clear.frame(maxWidth: .infinity, maxHeight: 1).accessibilityHidden(true)
        }
      }
      .frame(height: 96, alignment: .bottom)
      .tollChartTypeLimit()
    }
  }
}

/// When it stopped you, by hour from 10 pm to 6 am (48 pt at most), the busiest hour in amber.
private struct HoursCard: View {
  let insights: InsightsSnapshot

  var body: some View {
    InsightCard(title: Copy.Insights.when) {
      let top = max(1, insights.byHour.max() ?? 1)
      HStack(alignment: .bottom, spacing: 6) {
        ForEach(Array(insights.byHour.enumerated()), id: \.offset) { _, count in
          RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(count == top && count > 0 ? TollColor.accent : TollColor.bar)
            .frame(height: max(5, 48 * CGFloat(count) / CGFloat(top)))
            .frame(maxWidth: .infinity)
        }
      }
      .frame(height: 48, alignment: .bottom)
      .accessibilityHidden(true)
      HStack {
        Text(Copy.time(ClockTime(hour: 22), short: true))
        Spacer(minLength: 4)
        if let peak = insights.peakHour {
          Text(Copy.Insights.mostAt(Copy.Insights.hourName(peak)))
        }
        Spacer(minLength: 4)
        Text(Copy.time(ClockTime(hour: 6), short: true))
      }
      .tollType(.micro, TollColor.label2)
      .padding(.top, -4)
      .tollChartTypeLimit()
    }
  }
}
