import SwiftUI
import TollCore
import TollUI

/// Your nights (the design canvas's Insights), pushed from Home's "See all": everything from the log
/// on this phone. Apple's "Screen time after bedtime" card joins it with the report extension.
struct InsightsView: View {
  let log: [TollCore.Transition]
  @State private var range = InsightsSnapshot.Range.month

  var body: some View {
    let insights = InsightsSnapshot(log: log, now: Date(), calendar: .current, range: range)
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        ScreenTitle(Copy.Insights.title, kind: .pushed)
        Picker(Copy.Insights.title, selection: $range) {
          Text(Copy.Insights.week).tag(InsightsSnapshot.Range.week)
          Text(Copy.Insights.month).tag(InsightsSnapshot.Range.month)
          Text(Copy.Insights.all).tag(InsightsSnapshot.Range.all)
        }
        .pickerStyle(.segmented)
        .padding(.top, 16)
        if insights.isEmpty {
          Footnote(Copy.Insights.empty).padding(.top, 20)
        } else {
          AdaptiveStack(spacing: 28) {
            Stat(value: "\(insights.nights)", label: since(insights))
            Stat(value: Copy.Insights.hours(insights.hoursBlocked), label: Copy.Insights.hoursLabel)
          }
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
    .tollPushed(Copy.Insights.title)
  }

  private func since(_ insights: InsightsSnapshot) -> String {
    let day = insights.since?.formatted(.dateTime.month(.abbreviated).day()) ?? ""
    return Copy.Insights.nightsSince(day)
  }
}

/// A card with a 15 pt semibold title and a note at its right (the canvas's Insights cards).
private struct InsightCard<Content: View>: View {
  let title: String
  let note: String?
  var noteColor = TollColor.label2
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .firstTextBaseline) {
        Text(title).tollType(.link, TollColor.label).accessibilityAddTraits(.isHeader)
        Spacer(minLength: 8)
        if let note { Text(note).tollType(.trailing, noteColor) }
      }
      content
    }
    .padding(TollSpacing.cardPadding)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      TollColor.surface, in: RoundedRectangle(cornerRadius: TollRadius.card, style: .continuous))
  }
}

/// Times it stopped you, one bar per week (at most 56 pt), the latest in amber.
private struct WeeksCard: View {
  let insights: InsightsSnapshot

  var body: some View {
    InsightCard(
      title: Copy.Insights.stopped, note: insights.change.map(Copy.Insights.change),
      noteColor: (insights.change ?? 0) <= 0 ? TollColor.ok : TollColor.label2
    ) {
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
    InsightCard(title: Copy.Insights.when, note: nil) {
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
