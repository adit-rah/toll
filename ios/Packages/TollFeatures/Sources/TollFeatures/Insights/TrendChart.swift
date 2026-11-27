import SwiftUI
import TollCore
import TollUI

/// A measure's last two weeks, one column a night, oldest at the left: a dot for a time (earlier
/// higher, as a day reads down) or a bar for an amount. The first nights' level is a dashed line,
/// the last week's a solid one over its own nights, so a change reads as the gap between them
/// without words. How steady draws each as a band. A night without a value is left empty.
struct TrendChart: View {
  let chart: SleepTrends.Chart

  var body: some View {
    Canvas { context, size in
      let values = chart.values
      guard !values.isEmpty else { return }
      let scale = Scale(chart: chart, height: size.height)
      let step = size.width / CGFloat(values.count)
      let recentFrom = values.count - chart.recentColumns
      for (column, value) in values.enumerated() {
        guard let value else { continue }
        let x = step * (CGFloat(column) + 0.5)
        let recent = column >= recentFrom
        let colour = recent ? TollColor.label2 : TollColor.label3
        switch chart.style {
        case .times:
          let y = scale.y(value)
          context.fill(
            Path(ellipseIn: CGRect(x: x - 3.5, y: y - 3.5, width: 7, height: 7)),
            with: .color(colour))
        case .bars:
          let top = scale.y(value)
          let width = min(12, step * 0.6)
          let rect = CGRect(
            x: x - width / 2, y: top, width: width, height: max(2, size.height - top))
          context.fill(
            Path(roundedRect: rect, cornerRadius: min(3, width / 2)),
            with: .color(recent ? TollColor.label2 : TollColor.bar))
        }
      }
      if let first = chart.first {
        band(first, in: context, from: 0, to: size.width, scale: scale, dashed: true)
      }
      if let recent = chart.recent {
        band(
          recent, in: context, from: step * CGFloat(recentFrom), to: size.width, scale: scale,
          dashed: false)
      }
    }
    .accessibilityHidden(true)
  }

  /// A level as a line, or a range as a soft band edged by lines.
  private func band(
    _ band: SleepTrends.Band, in context: GraphicsContext, from x0: CGFloat, to x1: CGFloat,
    scale: Scale, dashed: Bool
  ) {
    let ys = [scale.y(band.low), scale.y(band.high)]
    if band.high > band.low, !dashed, let top = ys.min(), let bottom = ys.max() {
      context.fill(
        Path(CGRect(x: x0, y: top, width: x1 - x0, height: bottom - top)),
        with: .color(TollColor.label.opacity(0.08)))
    }
    for y in Set(ys) {
      var line = Path()
      line.move(to: CGPoint(x: x0, y: y))
      line.addLine(to: CGPoint(x: x1, y: y))
      context.stroke(
        line, with: .color(dashed ? TollColor.label3 : TollColor.label),
        style: StrokeStyle(
          lineWidth: dashed ? 1.5 : 2, lineCap: .round, dash: dashed ? [4, 3] : []))
    }
  }

  /// Values to points: times from the earliest at the top to the latest at the bottom; amounts
  /// from nothing at the bottom.
  private struct Scale {
    let low: Double
    let high: Double
    let height: CGFloat
    let times: Bool

    init(chart: SleepTrends.Chart, height: CGFloat) {
      let bands = [chart.first, chart.recent].compactMap { $0 }
      let all = chart.values.compactMap { $0 } + bands.flatMap { [$0.low, $0.high] }
      times = chart.style == .times
      var low = times ? all.min() ?? 0 : 0
      var high = all.max() ?? 1
      // A flat run still gets room, so its dots sit mid-chart instead of on an edge.
      if high - low < (times ? 30 : 1) {
        let mid = (high + low) / 2
        low = times ? mid - 15 : 0
        high = times ? mid + 15 : max(1, high)
      }
      self.low = low
      self.high = high
      self.height = height
    }

    func y(_ value: Double) -> CGFloat {
      let inset: CGFloat = 4
      let fraction = CGFloat((value - low) / (high - low))
      let span = height - inset * 2
      return times ? inset + fraction * span : inset + (1 - fraction) * span
    }
  }
}
