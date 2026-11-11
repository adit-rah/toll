import Charts
import SwiftUI
import TollCore
import TollUI

/// Insights · Me (I-1…I-9). Computed on the device; works in solo mode. Each card is its own view
/// reading only what it draws, so choosing a day or a range redraws that card and no other chart.
struct MeInsightsView: View {
  let model: InsightsModel

  var body: some View {
    // Nothing until the first numbers exist: a screen of zeros that then changes reads as wrong data.
    if model.me.today != nil {
      WeekCard(model: model)
      DayCard(model: model)
      HourCard(model: model)
      WeekdayCard(model: model)
      AppCard(model: model)
      GatesCard(model: model)
      EightWeeksCard(model: model)
      TermCard(model: model)
    }
  }
}

private struct WeekCard: View {
  let model: InsightsModel

  var body: some View {
    let this = model.me.thisWeek
    let last = model.me.lastWeek
    ChartCard(title: Copy.Insights.thisWeekVsLast) {
      ViewThatFits(in: .horizontal) {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          count(this.passes)
          Spacer(minLength: 12)
          lastWeek(last.passes)
        }
        VStack(alignment: .leading, spacing: 2) {
          count(this.passes)
          lastWeek(last.passes)
        }
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(Copy.ShareCards.week(this.passes, last: last.passes))
      MetricStrip(items: [
        .init(
          label: Copy.FriendDetail.held, value: this.heldPercent.map(Copy.percent) ?? "—",
          previous: last.heldPercent.map(Copy.percent)),
        .init(
          label: Copy.FriendDetail.waited, value: Copy.minutes(this.waitMinutes), previous: "\(last.waitMinutes)"),
        .init(label: Copy.Insights.cleanDays, value: "\(this.cleanDays)", previous: "\(last.cleanDays)"),
        .init(
          label: Copy.Insights.tollOpens, value: "\(model.me.tollOpensThis)",
          previous: "\(model.me.tollOpensLast)"),
      ])
    }
  }

  private func count(_ passes: Int) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      HeroNumber("\(passes)", size: 40)
      Text(Copy.passes(passes)).tollText(.body)
    }
  }

  private func lastWeek(_ passes: Int) -> some View {
    Text(Copy.FriendDetail.lastWeek("\(passes)")).tollText(.subhead).monospacedDigit()
  }
}

private struct DayCard: View {
  let model: InsightsModel

  var body: some View {
    let days = model.me.days
    let today = model.me.today
    ChartCard(title: Copy.Insights.dayByDay) {
      DayPairBars(pairs: DayPairBars.weekdayPairs(days), today: today, selected: model.selectedDay) { day in select(day) }
        .accessibilityElement(children: .ignore)
        .accessibilityValue(selection(in: days).map { heading($0) } ?? "")
        .accessibilityAdjustableAction { direction in step(direction, in: days) }
        .audioGraph(
          Copy.Insights.dayByDay, labels: days.map { ChartLabels.day($0.day) }, values: days.map { Double($0.passes) })
      if let day = selection(in: days) {
        VStack(alignment: .leading, spacing: 4) {
          Text(heading(day)).font(TollFont.subheadMedium).foregroundStyle(TollColor.label).monospacedDigit()
          ForEach(day.passList) { pass in
            Text(passText(pass)).tollText(.caption).monospacedDigit()
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .transition(.opacity)
      }
    }
  }

  private func selection(in days: [DayMetrics]) -> DayMetrics? {
    model.selectedDay.flatMap { selected in days.first { $0.day == selected } }
  }

  private func select(_ day: TollDay) {
    if let today = model.me.today, day > today { return }
    withAnimation(Motion.stateChange) { model.selectedDay = model.selectedDay == day ? nil : day }
  }

  private func step(_ direction: AccessibilityAdjustmentDirection, in days: [DayMetrics]) {
    let past = days.filter { day in model.me.today.map { day.day <= $0 } ?? true }
    guard !past.isEmpty else { return }
    let current = past.firstIndex { $0.day == model.selectedDay } ?? past.count
    let next = direction == .decrement ? current - 1 : current + 1
    model.selectedDay = past[min(past.count - 1, max(0, next))].day
  }

  private func heading(_ day: DayMetrics) -> String {
    let date = model.math.start(of: day.day).formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    return "\(date)\(Copy.middleDot)\(day.passes) \(Copy.passes(day.passes))"
  }

  private func passText(_ pass: GateEvent) -> String {
    let app = Copy.Tags.display(pass.appRef.flatMap { model.me.tags[$0] })
    let time = Copy.clock(pass.occurredAt, offsetMinutes: pass.tzOffsetMinutes)
    return pass.free == true
      ? Copy.FriendRows.free(app, at: time) : Copy.FriendRows.waited(app, at: time, minutes: pass.waitMinutes ?? 0)
  }
}

private struct HourCard: View {
  let model: InsightsModel

  var body: some View {
    ChartCard(
      title: Copy.Insights.byHour, caption: model.lateCaption,
      range: ChartRange(
        Copy.Insights.week, Copy.Insights.eightWeeksToggle,
        selection: Binding(
          get: { model.hourRangeIsEightWeeks ? 1 : 0 }, set: { model.hourRangeIsEightWeeks = $0 == 1 }))
    ) {
      HourBars(
        values: model.hourRange.byHour.map(Double.init), lateStart: model.app.config.insights.lateStart,
        resetHour: model.app.config.gate.dayResetHour, title: Copy.Insights.byHour)
    }
  }
}

private struct WeekdayCard: View {
  let model: InsightsModel

  var body: some View {
    let averages = Weekday.allCases.map { (day: $0, value: model.me.weekdayAverages[$0] ?? 0) }
    let top = averages.map(\.value).max() ?? 0
    ChartCard(title: Copy.Insights.weekdays, caption: caption(averages)) {
      Chart {
        ForEach(averages, id: \.day) { row in
          BarMark(x: .value("day", ChartLabels.weekday(row.day)), y: .value("avg", row.value))
            .foregroundStyle(TollColor.accent)
            .cornerRadius(3)
        }
        // A hairline where the bars stand, so eight weeks of nothing still reads as a chart.
        RuleMark(y: .value("zero", 0.0))
          .foregroundStyle(TollColor.separator)
          .lineStyle(StrokeStyle(lineWidth: 1))
      }
      .chartYScale(domain: 0...(top > 0 ? top : 1))
      .chartXAxis {
        AxisMarks { value in
          AxisValueLabel {
            Text(value.as(String.self) ?? "").font(TollFont.micro).foregroundStyle(TollColor.label3)
          }
        }
      }
      .chartYAxis(.hidden)
      .frame(height: ChartHeight.bars)
      .audioGraph(
        Copy.Insights.weekdays, labels: averages.map { ChartLabels.weekdayName($0.day) }, values: averages.map(\.value))
    }
  }

  private func caption(_ averages: [(day: Weekday, value: Double)]) -> String? {
    guard model.me.eightWeeks.passes >= model.minN,
      let high = averages.max(by: { $0.value < $1.value }), let low = averages.min(by: { $0.value < $1.value }),
      high.value > low.value
    else { return nil }
    return Copy.Insights.weekdayRange(high: ChartLabels.weekdayName(high.day), low: ChartLabels.weekdayName(low.day))
  }
}

private struct AppCard: View {
  let model: InsightsModel

  var body: some View {
    let week = model.me.thisWeek
    let rows = appRows(week)
    let costly = week.byTag.filter { $0.value.waitMinutes > 0 }.max { $0.value.waitMinutes < $1.value.waitMinutes }
    let caption = week.passes >= model.minN
      ? costly.map { Copy.Insights.appCost(Copy.Tags.display($0.key), minutes: $0.value.waitMinutes) } : nil
    ChartCard(title: Copy.Insights.byApp, caption: caption) {
      if rows.isEmpty {
        Text(Copy.FriendDetail.noPasses).tollText(.subhead)
      } else {
        ValueBars(rows: rows, title: Copy.Insights.byApp)
      }
    }
  }

  /// Untagged apps and "Other" are one row: friends see both as the same thing.
  private func appRows(_ week: Metrics) -> [ValueBars.Row] {
    var byName: [String: Metrics.TagMetrics] = [:]
    for (tag, metrics) in week.byTag {
      let name = Copy.Tags.chip(tag ?? .other)
      byName[name, default: Metrics.TagMetrics()].passes += metrics.passes
      byName[name, default: Metrics.TagMetrics()].waitMinutes += metrics.waitMinutes
    }
    let top = max(1, byName.values.map(\.passes).max() ?? 1)
    return byName.sorted { ($0.value.passes, $1.key) > ($1.value.passes, $0.key) }.map { name, metrics in
      ValueBars.Row(
        id: name, name: name, fraction: Double(metrics.passes) / Double(top),
        value: "\(metrics.passes)\(Copy.middleDot)\(Copy.minutes(metrics.waitMinutes))", isMine: true)
    }
  }
}

private struct GatesCard: View {
  let model: InsightsModel

  var body: some View {
    let this = model.me.thisWeek
    let last = model.me.lastWeek
    ChartCard(title: Copy.Insights.gates, caption: model.gatesCaption) {
      MetricStrip(items: [
        .init(label: Copy.Insights.hits, value: "\(this.hits)", previous: "\(last.hits)"),
        .init(label: Copy.Insights.heldLabel, value: "\(this.held)", previous: "\(last.held)"),
        .init(label: Copy.Insights.abandoned, value: "\(this.abandoned)", previous: "\(last.abandoned)"),
      ])
    }
  }
}
