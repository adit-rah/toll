import SwiftUI

/// Design §3.15. Texture, not a chart: seven bars Monday to Sunday, no axis, no values. The caller
/// wraps it in a `Button` that opens Insights.
public struct WeekStrip: View {
  let counts: [Int]
  let todayIndex: Int?
  let dayNames: [String]
  let accessibilityTitle: String?
  let animateOnAppear: Bool
  @State private var grown: Bool
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private static let barWidth: CGFloat = 12
  private static let barGap: CGFloat = 6
  private static let maxHeight: CGFloat = 28
  private static let stubHeight: CGFloat = 2

  /// `counts` are passes per day, Monday first. `todayIndex` is 0 for Monday. `dayNames` default to
  /// the current calendar's weekday names, Monday first, for the spoken label.
  public init(
    counts: [Int], todayIndex: Int?, dayNames: [String]? = nil, accessibilityTitle: String? = nil,
    animateOnAppear: Bool = false
  ) {
    self.counts = Array((counts + Array(repeating: 0, count: 7)).prefix(7))
    self.todayIndex = todayIndex
    self.dayNames = dayNames ?? Self.mondayFirstWeekdays()
    self.accessibilityTitle = accessibilityTitle
    self.animateOnAppear = animateOnAppear
    _grown = State(initialValue: !animateOnAppear)
  }

  public var body: some View {
    HStack(alignment: .bottom, spacing: Self.barGap) {
      ForEach(counts.indices, id: \.self) { index in
        RoundedRectangle(cornerRadius: 2, style: .continuous)
          .fill(index == todayIndex ? TollColor.accent : TollColor.neutralBar)
          .frame(width: Self.barWidth, height: height(for: counts[index]))
          .scaleEffect(x: 1, y: grown || reduceMotion ? 1 : 0.01, anchor: .bottom)
          .opacity(grown || !reduceMotion ? 1 : 0)
          .animation(
            Motion.staggered(index, step: Motion.Stagger.weekStrip), value: grown)
      }
    }
    .frame(height: Self.maxHeight, alignment: .bottom)
    .onAppear {
      if !grown { grown = true }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(spoken)
  }

  private func height(for count: Int) -> CGFloat {
    let top = counts.max() ?? 0
    guard count > 0, top > 0 else { return Self.stubHeight }
    return max(Self.stubHeight, Self.maxHeight * CGFloat(count) / CGFloat(top))
  }

  private var spoken: String {
    let days = counts.indices.map { index in
      let name = index < dayNames.count ? dayNames[index] : ""
      return "\(name) \(counts[index])"
    }
    return AccessibilitySentence.join([accessibilityTitle] + days)
  }

  private static func mondayFirstWeekdays() -> [String] {
    let symbols = Calendar.current.weekdaySymbols
    guard symbols.count == 7 else { return Array(repeating: "", count: 7) }
    return Array(symbols[1...] + symbols[..<1])
  }
}
