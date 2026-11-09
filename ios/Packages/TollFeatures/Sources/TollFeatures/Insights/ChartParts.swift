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

  static func weekday(_ day: Weekday) -> String {
    Calendar.current.shortStandaloneWeekdaySymbols[day.rawValue % 7]
  }

  static func day(_ day: TollDay) -> String { "\(weekday(day.weekday)) \(day.day)" }
}

/// A 24-bar hour histogram with the late hours lightly shaded (I-3, I-12, I-17).
struct HourBars: View {
  let values: [Double]
  var overlay: [Double]? = nil
  let lateStart: Int
  let resetHour: Int
  let title: String

  var body: some View {
    Chart {
      RectangleMark(xStart: .value("h", lateStart), xEnd: .value("h", 24))
        .foregroundStyle(TollColor.accentSoft)
      RectangleMark(xStart: .value("h", 0), xEnd: .value("h", resetHour))
        .foregroundStyle(TollColor.accentSoft)
      ForEach(Array(values.enumerated()), id: \.offset) { hour, value in
        BarMark(x: .value("h", Double(hour) + 0.5), y: .value("n", value), width: .ratio(0.7))
          .foregroundStyle(overlay == nil ? TollColor.accent : TollColor.neutralBar)
      }
      if let overlay {
        // Yours over theirs: a step outline in the accent, so neither hides the other.
        ForEach(Array(overlay.enumerated()), id: \.offset) { hour, value in
          LineMark(x: .value("h", Double(hour) + 0.5), y: .value("you", value))
            .interpolationMethod(.stepCenter)
            .lineStyle(StrokeStyle(lineWidth: 1.5))
            .foregroundStyle(TollColor.accent)
        }
      }
    }
    .chartXScale(domain: 0...24)
    .chartXAxis {
      AxisMarks(values: [0, 6, 12, 18]) { value in
        AxisValueLabel { Text(ChartLabels.hour(value.as(Int.self) ?? 0)).monospacedDigit() }
      }
    }
    .chartYAxis(.hidden)
    .frame(height: ChartHeight.histogram)
    .audioGraph(title, labels: ChartLabels.hours, values: values)
  }
}

/// A distribution histogram with your bin in the accent (I-10, I-15). Nobody is named on it.
struct BinBars: View {
  let bins: [(from: Int, to: Int, count: Int, mine: Bool)]
  let title: String

  var body: some View {
    Chart(Array(bins.enumerated()), id: \.offset) { _, bin in
      BarMark(x: .value("bin", "\(bin.from)–\(bin.to)"), y: .value("n", bin.count))
        .foregroundStyle(bin.mine ? TollColor.accent : TollColor.neutralBar)
    }
    .chartYAxis(.hidden)
    .frame(height: ChartHeight.histogram)
    .audioGraph(title, labels: bins.map { "\($0.from)–\($0.to)" }, values: bins.map { Double($0.count) })
  }
}
