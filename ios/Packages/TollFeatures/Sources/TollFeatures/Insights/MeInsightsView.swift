import Charts
import SwiftUI
import TollCore
import TollUI

/// Insights · Me (I-1…I-9). Computed on the device; works in solo mode.
struct MeInsightsView: View {
  @Bindable var model: InsightsModel

  private var me: InsightsModel.MeData { model.me }

  var body: some View {
    VStack(spacing: 16) {
      weekVsLast
      dayByDay
      ChartCard(
        title: Copy.Insights.byHour, caption: model.lateCaption,
        range: ChartRange(
          Copy.Insights.week, Copy.Insights.eightWeeksToggle,
          selection: Binding(get: { model.hourRangeIsEightWeeks ? 1 : 0 }, set: { model.hourRangeIsEightWeeks = $0 == 1 }))
      ) {
        HourBars(
          values: me.hourRange.byHour.map(Double.init), lateStart: model.app.config.insights.lateStart,
          resetHour: model.app.config.gate.dayResetHour, title: Copy.Insights.byHour)
      }
      weekdays
      byApp
      gates
      eightWeeks
      term
    }
  }

  private var weekVsLast: some View {
    ChartCard(title: Copy.Insights.thisWeekVsLast) {
      VStack(alignment: .leading, spacing: 12) {
        Text(Copy.Home.week(me.thisWeek.passes, last: me.lastWeek.passes)).tollText(.headline)
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
          GridRow {
            MetricPair(label: Copy.FriendDetail.held, value: me.thisWeek.heldPercent.map(Copy.percent) ?? "—",
                       previous: me.lastWeek.heldPercent.map(Copy.percent))
            MetricPair(label: Copy.Insights.waitMinutes, value: "\(me.thisWeek.waitMinutes)", previous: "\(me.lastWeek.waitMinutes)")
          }
          GridRow {
            MetricPair(label: Copy.Insights.cleanDays, value: "\(me.thisWeek.cleanDays)", previous: "\(me.lastWeek.cleanDays)")
            MetricPair(label: Copy.Insights.tollOpens, value: "\(me.tollOpensThis)", previous: "\(me.tollOpensLast)")
          }
        }
      }
    }
  }

  private var dayByDay: some View {
    let today = model.math.day(containing: model.app.deps.clock.now)
    return ChartCard(title: Copy.Insights.dayByDay) {
      Chart(me.days, id: \.day) { day in
        BarMark(x: .value("day", day.day.description), y: .value("passes", day.passes))
          .foregroundStyle(day.day < model.thisWeekStart ? TollColor.neutralBar : TollColor.accent)
          .lineStyle(StrokeStyle(lineWidth: day.day == today ? 1.5 : 0))
      }
      .chartXAxis(.hidden)
      .chartYAxis(.hidden)
      .chartOverlay { proxy in
        Rectangle().fill(.clear).contentShape(Rectangle())
          .onTapGesture { location in
            if let key: String = proxy.value(atX: location.x) {
              model.selectedDay = me.days.first { $0.day.description == key }
            }
          }
      }
      .frame(height: ChartHeight.bars)
      .audioGraph(Copy.Insights.dayByDay, labels: me.days.map { ChartLabels.day($0.day) }, values: me.days.map { Double($0.passes) })
      if let day = model.selectedDay {
        VStack(alignment: .leading, spacing: 4) {
          Text("\(ChartLabels.day(day.day))\(Copy.middleDot)\(day.passes) \(Copy.passes(day.passes))").tollText(.subheadMedium)
          ForEach(day.passList) { pass in
            Text(passText(pass)).tollText(.caption)
          }
        }
        .transition(.opacity)
      }
    }
  }

  private func passText(_ pass: GateEvent) -> String {
    let app = Copy.Tags.display(pass.appRef.flatMap { model.tags[$0] })
    let time = Copy.clock(pass.occurredAt, offsetMinutes: pass.tzOffsetMinutes)
    return pass.free == true ? Copy.FriendRows.free(app, at: time) : Copy.FriendRows.waited(app, at: time, minutes: pass.waitMinutes ?? 0)
  }

  private var weekdays: some View {
    let averages = Weekday.allCases.map { (day: $0, value: me.weekdayAverages[$0] ?? 0) }
    let caption: String? = {
      guard me.weeks.reduce(0, { $0 + $1.passes }) >= model.minN,
        let high = averages.max(by: { $0.value < $1.value }), let low = averages.min(by: { $0.value < $1.value })
      else { return nil }
      let name = { (d: Weekday) in Calendar.current.standaloneWeekdaySymbols[d.rawValue % 7] }
      return Copy.Insights.weekdayRange(high: name(high.day), low: name(low.day))
    }()
    return ChartCard(title: Copy.Insights.weekdays, caption: caption) {
      Chart(averages, id: \.day) { row in
        BarMark(x: .value("day", ChartLabels.weekday(row.day)), y: .value("avg", row.value))
          .foregroundStyle(TollColor.accent)
      }
      .chartYAxis(.hidden)
      .frame(height: ChartHeight.bars)
      .audioGraph(Copy.Insights.weekdays, labels: averages.map { ChartLabels.weekday($0.day) }, values: averages.map(\.value))
    }
  }

  private var byApp: some View {
    let rows = me.thisWeek.byTag.map { (name: Copy.Tags.display($0.key), passes: $0.value.passes, minutes: $0.value.waitMinutes) }
      .sorted { $0.passes > $1.passes }
    let top = rows.first { $0.minutes > 0 }
    let caption = me.thisWeek.passes >= model.minN ? top.map { Copy.Insights.appCost($0.name, minutes: $0.minutes) } : nil
    return ChartCard(title: Copy.Insights.byApp, caption: caption) {
      Chart(rows, id: \.name) { row in
        BarMark(x: .value("passes", row.passes), y: .value("app", row.name))
          .foregroundStyle(TollColor.accent)
          .annotation(position: .trailing) { Text("\(row.passes)").tollText(.captionNumber) }
      }
      .chartXAxis(.hidden)
      .frame(height: max(ChartHeight.bars / 2, CGFloat(rows.count) * 32))
      .audioGraph(Copy.Insights.byApp, labels: rows.map(\.name), values: rows.map { Double($0.passes) })
    }
  }

  private var gates: some View {
    ChartCard(title: Copy.Insights.gates, caption: model.gatesCaption) {
      HStack {
        MetricPair(label: Copy.Insights.hits, value: "\(me.thisWeek.hits)", previous: "\(me.lastWeek.hits)")
        MetricPair(label: Copy.Insights.heldLabel, value: "\(me.thisWeek.held)", previous: "\(me.lastWeek.held)")
        MetricPair(label: Copy.Insights.abandoned, value: "\(me.thisWeek.abandoned)", previous: "\(me.lastWeek.abandoned)")
      }
    }
  }

  private var eightWeeks: some View {
    ChartCard(title: Copy.Insights.eightWeeks, caption: model.examCaption) {
      Chart {
        ForEach(me.weeks, id: \.week) { row in
          if model.me.examWeeks.contains(row.week) {
            RectangleMark(x: .value("week", row.week.description), width: .ratio(1))
              .foregroundStyle(TollColor.accentSoft)
          }
          LineMark(x: .value("week", row.week.description), y: .value("passes", row.passes))
            .foregroundStyle(TollColor.accent)
        }
      }
      .chartXAxis(.hidden)
      .chartYAxis(.hidden)
      .frame(height: ChartHeight.line)
      .audioGraph(Copy.Insights.eightWeeks, labels: me.weeks.map(\.week.description), values: me.weeks.map { Double($0.passes) })
      ScrollView(.horizontal, showsIndicators: false) {
        HStack {
          ForEach(me.weeks, id: \.week) { row in
            ChoiceChip(ChartLabels.day(row.week), isSelected: me.examWeeks.contains(row.week)) {
              Task { await model.toggleExamWeek(row.week) }
            }
          }
        }
      }
      .accessibilityLabel(Copy.Insights.markExamWeek)
    }
  }

  private var term: some View {
    let maxPasses = max(1, me.term.map(\.passes).max() ?? 1)
    return ChartCard(title: Copy.Insights.term) {
      Chart(me.term, id: \.day) { day in
        RectangleMark(
          x: .value("weekday", day.day.weekday.rawValue), y: .value("week", day.day.weekStart.description),
          width: .ratio(0.9), height: .ratio(0.9)
        )
        .foregroundStyle(day.active ? TollColor.heat[min(4, day.passes * 5 / (maxPasses + 1))] : .clear)
      }
      .chartXAxis(.hidden)
      .chartYAxis(.hidden)
      .frame(height: CGFloat(max(1, me.term.count / 7)) * ChartHeight.heatmapRow)
      .audioGraph(Copy.Insights.term, labels: me.term.map(\.day.description), values: me.term.map { Double($0.passes) })
    }
  }
}
