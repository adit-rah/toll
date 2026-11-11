import Accessibility
import Charts
import SwiftUI
import TollCore
import TollUI

/// Audio graphs for every chart (insights spec §4, E8.42): one series of labelled values.
struct SeriesDescriptor: AXChartDescriptorRepresentable {
  let title: String
  let labels: [String]
  let values: [Double]

  func makeChartDescriptor() -> AXChartDescriptor {
    let xAxis = AXCategoricalDataAxisDescriptor(title: title, categoryOrder: labels)
    let maxValue = max(values.max() ?? 1, 1)
    let yAxis = AXNumericDataAxisDescriptor(title: title, range: 0...maxValue, gridlinePositions: []) {
      String(Int($0.rounded()))
    }
    let series = AXDataSeriesDescriptor(
      name: title, isContinuous: false,
      dataPoints: zip(labels, values).map { AXDataPoint(x: $0.0, y: $0.1) })
    return AXChartDescriptor(title: title, summary: nil, xAxis: xAxis, yAxis: yAxis, series: [series])
  }
}

extension View {
  func audioGraph(_ title: String, labels: [String], values: [Double]) -> some View {
    accessibilityChartDescriptor(SeriesDescriptor(title: title, labels: labels, values: values))
      .accessibilityLabel(title)
  }
}

enum ChartLabels {
  static func hour(_ h: Int) -> String { Copy.Schedules.time(ClockTime(hour: h)) }
  static let hours = (0..<24).map(hour)

  // Read once: `Calendar.current` builds its symbol arrays on every call and charts ask per mark.
  private static let shortWeekdays = Calendar.current.shortStandaloneWeekdaySymbols
  private static let wideWeekdays = Calendar.current.standaloneWeekdaySymbols

  static func weekday(_ day: Weekday) -> String { symbol(day, in: shortWeekdays) }
  static func weekdayName(_ day: Weekday) -> String { symbol(day, in: wideWeekdays) }

  private static func symbol(_ day: Weekday, in symbols: [String]) -> String {
    let index = day.rawValue % 7
    return index < symbols.count ? symbols[index] : ""
  }

  static func day(_ day: TollDay) -> String { "\(weekday(day.weekday)) \(day.day)" }
  static func bin(from: Int, to: Int) -> String { "\(from)–\(to)" }
}

/// A 24-bar hour histogram with the late hours lightly shaded (I-3, I-12, I-17).
struct HourBars: View {
  let values: [Double]
  var overlay: [Double]? = nil
  let lateStart: Int
  let resetHour: Int
  let title: String

  var body: some View {
    // An explicit ceiling: with no passes at all the scale would otherwise collapse to nothing.
    let top = max(values.max() ?? 0, overlay?.max() ?? 0)
    Chart {
      RectangleMark(xStart: .value("h", lateStart), xEnd: .value("h", 24))
        .foregroundStyle(TollColor.accentSoft)
      RectangleMark(xStart: .value("h", 0), xEnd: .value("h", resetHour))
        .foregroundStyle(TollColor.accentSoft)
      ForEach(values.indices, id: \.self) { hour in
        BarMark(x: .value("h", Double(hour) + 0.5), y: .value("n", values[hour]), width: .ratio(0.7))
          .foregroundStyle(overlay == nil ? TollColor.accent : TollColor.neutralBar)
          .cornerRadius(2)
      }
      if let overlay {
        // Yours over theirs: a step outline in the accent, so neither hides the other.
        ForEach(overlay.indices, id: \.self) { hour in
          LineMark(x: .value("h", Double(hour) + 0.5), y: .value("you", overlay[hour]))
            .interpolationMethod(.stepCenter)
            .lineStyle(StrokeStyle(lineWidth: 1.5))
            .foregroundStyle(TollColor.accent)
        }
      }
      // A hairline where the bars stand, so an hour chart with no passes yet still reads as a chart.
      RuleMark(y: .value("zero", 0.0))
        .foregroundStyle(TollColor.separator)
        .lineStyle(StrokeStyle(lineWidth: 1))
    }
    .chartXScale(domain: 0...24)
    .chartYScale(domain: 0...(top > 0 ? top : 1))
    .chartXAxis {
      AxisMarks(values: [0, 6, 12, 18]) { value in
        AxisValueLabel {
          Text(ChartLabels.hour(value.as(Int.self) ?? 0))
            .font(TollFont.micro).foregroundStyle(TollColor.label3).monospacedDigit()
        }
      }
    }
    .chartYAxis(.hidden)
    .frame(height: ChartHeight.histogram)
    .audioGraph(title, labels: ChartLabels.hours, values: values)
  }
}

/// A distribution histogram with your bin in the accent (I-10, I-15). Nobody is named on it.
struct BinBars: View {
  struct Bar: Identifiable {
    var id: String
    var count: Int
    var mine: Bool
  }

  let bars: [Bar]
  let title: String

  var body: some View {
    Chart(bars) { bar in
      BarMark(x: .value("bin", bar.id), y: .value("n", bar.count))
        .foregroundStyle(bar.mine ? TollColor.accent : TollColor.neutralBar)
        .cornerRadius(3)
    }
    .chartXAxis {
      AxisMarks { value in
        AxisValueLabel {
          Text(value.as(String.self) ?? "")
            .font(TollFont.micro).foregroundStyle(TollColor.label3).monospacedDigit()
        }
      }
    }
    .chartYAxis(.hidden)
    .frame(height: ChartHeight.histogram)
    .audioGraph(title, labels: bars.map(\.id), values: bars.map { Double($0.count) })
  }
}

/// Held % over the last weeks (I-13, I-16). A week with no hits has no percentage and is left out
/// rather than drawn as a fall to zero. The second series is dashed, so it is not colour alone.
struct PercentLines: View {
  struct Series: Identifiable {
    var id: String
    var points: [(week: String, percent: Int)]
    var isMine: Bool
  }

  /// Every week in order. Without it the axis takes its order from whichever series is drawn first,
  /// and a week that series skipped lands at the end.
  let weeks: [String]
  let series: [Series]
  let title: String

  var body: some View {
    Chart {
      ForEach(series) { line in
        ForEach(line.points, id: \.week) { point in
          LineMark(
            x: .value("week", point.week), y: .value("held", point.percent), series: .value("who", line.id)
          )
          .foregroundStyle(line.isMine ? TollColor.accent : TollColor.neutralBar)
          .lineStyle(StrokeStyle(lineWidth: 2, dash: line.isMine ? [] : [4, 3]))
        }
      }
    }
    .chartXScale(domain: weeks)
    .chartYScale(domain: 0...100)
    .chartXAxis(.hidden)
    .chartYAxis {
      AxisMarks(values: [0, 50, 100]) { value in
        AxisGridLine()
        AxisValueLabel {
          Text(Copy.percent(value.as(Int.self) ?? 0))
            .font(TollFont.micro).foregroundStyle(TollColor.label3).monospacedDigit()
        }
      }
    }
    .frame(height: ChartHeight.line)
    .audioGraph(
      title, labels: series.first?.points.map(\.week) ?? [],
      values: series.first?.points.map { Double($0.percent) } ?? [])
  }
}
