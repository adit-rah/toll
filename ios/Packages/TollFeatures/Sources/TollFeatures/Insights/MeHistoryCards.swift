import Charts
import SwiftUI
import TollCore
import TollUI

/// Eight weeks with exam weeks shaded (I-7, I-9).
struct EightWeeksCard: View {
  let model: InsightsModel

  var body: some View {
    let weeks = model.me.weeks
    let marked = model.examWeeks
    let top = weeks.map(\.passes).max() ?? 0
    ChartCard(title: Copy.Insights.eightWeeks, caption: model.examCaption) {
      Chart {
        ForEach(weeks) { week in
          if marked.contains(week.start) {
            RectangleMark(x: .value("week", week.label), width: .ratio(1))
              .foregroundStyle(TollColor.accentSoft)
          }
          LineMark(x: .value("week", week.label), y: .value("passes", week.passes))
            .foregroundStyle(TollColor.accent)
            .lineStyle(StrokeStyle(lineWidth: 2))
        }
      }
      .chartXScale(domain: weeks.map(\.label))
      .chartYScale(domain: 0...(top > 0 ? top : 1))
      .chartXAxis(.hidden)
      .chartYAxis(.hidden)
      .frame(height: ChartHeight.line)
      .audioGraph(Copy.Insights.eightWeeks, labels: weeks.map(\.label), values: weeks.map { Double($0.passes) })
      VStack(alignment: .leading, spacing: 4) {
        Text(Copy.Insights.examWeeks).tollText(.caption)
        FlowLayout(spacing: 8, centred: false) {
          ForEach(weeks) { week in
            ChoiceChip(week.label, isSelected: marked.contains(week.start)) {
              Task { await model.toggleExamWeek(week.start) }
            }
            .accessibilityLabel(AccessibilitySentence.join([Copy.Insights.markExamWeek, week.label]))
          }
        }
      }
    }
  }
}

/// Hidden until there is a first event: the term starts there (insights §9 `termStart`).
struct TermCard: View {
  let model: InsightsModel

  var body: some View {
    let term = model.me.term
    if term.contains(where: \.active) {
      let top = max(1, term.map(\.passes).max() ?? 1)
      ChartCard(title: Copy.Insights.term) {
        Chart(term, id: \.day) { day in
          RectangleMark(
            x: .value("weekday", ChartLabels.weekday(day.day.weekday)),
            y: .value("week", day.day.weekStart.description),
            width: .ratio(0.9), height: .ratio(0.9)
          )
          .foregroundStyle(day.active ? TollColor.heat[min(4, day.passes * 5 / (top + 1))] : .clear)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: CGFloat(max(1, term.count / 7)) * ChartHeight.heatmapRow)
        .audioGraph(Copy.Insights.term, labels: term.map(\.day.description), values: term.map { Double($0.passes) })
      }
    }
  }
}
