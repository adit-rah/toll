import SwiftUI
import TollCore
import TollData
import TollUI

/// Your nights (the design canvas): from the log on this phone. "Phone after bedtime" is Apple's
/// number and can only be shown by Apple's own report view; it comes with that extension.
struct InsightsView: View {
  let log: [TollCore.Transition]
  @State private var range = InsightsSnapshot.Range.all
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    let insights = InsightsSnapshot(log: log, now: Date(), calendar: .current, range: range)
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: TollSpacing.groupGap) {
          Picker(Copy.Insights.title, selection: $range) {
            Text(Copy.Insights.week).tag(InsightsSnapshot.Range.week)
            Text(Copy.Insights.month).tag(InsightsSnapshot.Range.month)
            Text(Copy.Insights.all).tag(InsightsSnapshot.Range.all)
          }
          .pickerStyle(.segmented)
          if insights.isEmpty {
            Footnote(Copy.Insights.empty)
          } else {
            HStack(alignment: .top, spacing: 12) {
              Stat(value: "\(insights.nights)", label: since(insights))
              Stat(
                value: Copy.Insights.hours(insights.hoursBlocked), label: Copy.Insights.hoursLabel)
            }
            WeeksCard(insights: insights)
            HoursCard(insights: insights)
          }
        }
        .tollGutter()
        .padding(.vertical, TollSpacing.groupGap)
      }
      .background(TollColor.bg)
      .animation(Motion.stateChange, value: range)
      .navigationTitle(Copy.Insights.title)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) { Button(Copy.Setup.done) { dismiss() } }
      }
    }
    .tint(TollColor.accent)
  }

  private func since(_ insights: InsightsSnapshot) -> String {
    let day = insights.since?.formatted(.dateTime.month(.abbreviated).day()) ?? ""
    return Copy.Insights.nightsSince(day)
  }
}

private struct Stat: View {
  let value: String
  let label: String

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(value).font(.system(.largeTitle, weight: .semibold)).monospacedDigit()
        .foregroundStyle(TollColor.label)
      Text(label).font(TollFont.caption).foregroundStyle(TollColor.label2)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }
}

private struct WeeksCard: View {
  let insights: InsightsSnapshot

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(Copy.Insights.stopped).font(TollFont.headline).foregroundStyle(TollColor.label)
      if let change = insights.change {
        Text(Copy.Insights.change(change))
          .font(TollFont.captionMedium)
          .foregroundStyle(change <= 0 ? TollColor.ok : TollColor.label2)
      }
      let top = max(1, insights.weeks.max() ?? 1)
      ForEach(Array(insights.weeks.enumerated()), id: \.offset) { index, count in
        HStack(spacing: 10) {
          Text(Copy.Insights.weekLabel(index + 1)).font(TollFont.caption)
            .foregroundStyle(TollColor.label2).frame(width: 64, alignment: .leading)
          GeometryReader { proxy in
            Capsule()
              .fill(index == insights.weeks.count - 1 ? TollColor.accent : TollColor.bar)
              .frame(width: max(6, proxy.size.width * CGFloat(count) / CGFloat(top)))
          }
          .frame(height: 10)
          Text("\(count)").font(TollFont.captionNumber).foregroundStyle(TollColor.label)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Copy.Insights.weekLabel(index + 1)), \(count)")
      }
    }
    .padding(TollSpacing.cardPadding)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      TollColor.surface, in: RoundedRectangle(cornerRadius: TollRadius.card, style: .continuous))
  }
}

private struct HoursCard: View {
  let insights: InsightsSnapshot
  private let labels = ["10 pm", "2 am", "6 am"]

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(Copy.Insights.when).font(TollFont.headline).foregroundStyle(TollColor.label)
      let top = max(1, insights.byHour.max() ?? 1)
      HStack(alignment: .bottom, spacing: 4) {
        ForEach(Array(insights.byHour.enumerated()), id: \.offset) { index, count in
          RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(count == top && count > 0 ? TollColor.accent : TollColor.bar)
            .frame(height: max(4, 60 * CGFloat(count) / CGFloat(top)))
            .frame(maxWidth: .infinity)
        }
      }
      .frame(height: 60, alignment: .bottom)
      .accessibilityHidden(true)
      HStack {
        ForEach(labels, id: \.self) { Text($0).frame(maxWidth: .infinity, alignment: .leading) }
      }
      .font(TollFont.micro).foregroundStyle(TollColor.label2)
      if let peak = insights.peakHour {
        let hour =
          Calendar.current.date(bySettingHour: peak, minute: 0, second: 0, of: Date()) ?? Date()
        Text(Copy.Insights.mostAt(Copy.time(hour))).font(TollFont.caption).foregroundStyle(
          TollColor.label2)
      }
    }
    .padding(TollSpacing.cardPadding)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      TollColor.surface, in: RoundedRectangle(cornerRadius: TollRadius.card, style: .continuous))
  }
}
