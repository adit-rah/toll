import SwiftUI

/// A two-option range toggle for a chart card ("This week" / "4 weeks"). Never more than two.
public struct ChartRange {
  public var options: [String]
  public var selection: Binding<Int>

  public init(_ first: String, _ second: String, selection: Binding<Int>) {
    self.options = [first, second]
    self.selection = selection
  }
}

/// Fixed chart heights inside a `ChartCard` (design §3.11).
public enum ChartHeight {
  public static let bars: CGFloat = 160
  public static let line: CGFloat = 140
  public static let histogram: CGFloat = 160
  public static let heatmapRow: CGFloat = 20
}

extension View {
  /// The card every Insights block sits in (design §3.11): `surface`, 16 pt padding, 16 pt corners,
  /// as wide as the column so a stack of them shares both edges.
  public func tollCard() -> some View {
    padding(TollSpacing.cardPadding)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        TollColor.surface,
        in: RoundedRectangle(cornerRadius: TollRadius.card, style: .continuous))
  }
}

/// Design §3.11. One chart per card, at one of the `ChartHeight`s.
public struct ChartCard<Chart: View>: View {
  let title: String
  let caption: String?
  let range: ChartRange?
  let chart: Chart

  public init(
    title: String, caption: String? = nil, range: ChartRange? = nil,
    @ViewBuilder chart: () -> Chart
  ) {
    self.title = title
    self.caption = caption
    self.range = range
    self.chart = chart()
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      ViewThatFits(in: .horizontal) {
        HStack(alignment: .firstTextBaseline) {
          titleText
          Spacer(minLength: 12)
          toggle
        }
        VStack(alignment: .leading, spacing: 8) {
          titleText
          toggle
        }
      }
      chart
      if let caption {
        // Inside a lazy stack a caption is measured before it is placed; without this a two-line
        // caption can be given one line's height and truncate.
        Text(caption)
          .tollText(.caption)
          .monospacedDigit()
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .tollCard()
  }

  private var titleText: some View {
    Text(title)
      .font(TollFont.headline)
      .foregroundStyle(TollColor.label)
      .fixedSize(horizontal: false, vertical: true)
      .accessibilityAddTraits(.isHeader)
  }

  @ViewBuilder
  private var toggle: some View {
    if let range {
      Picker(title, selection: range.selection) {
        ForEach(range.options.indices, id: \.self) { index in
          Text(range.options[index]).tag(index)
        }
      }
      .pickerStyle(.segmented)
      .fixedSize()
    }
  }
}
