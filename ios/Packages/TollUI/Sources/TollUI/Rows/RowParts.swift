import SwiftUI
import TollCore

/// Week-on-week change in passes as a fraction (-0.23 is 23% fewer), the value
/// `Copy.FriendRows.trend` and `trendAccessibility` take.
public struct Trend: Hashable, Sendable {
  public var fraction: Double

  public init(fraction: Double) {
    self.fraction = fraction
  }
}

/// "▼ 23%" in `caption`. The arrow carries direction so the trend is never colour alone, and it is
/// never coloured either: a trend is a fact, not a verdict.
public struct TrendLabel: View {
  let trend: Trend

  public init(_ trend: Trend) {
    self.trend = trend
  }

  public var body: some View {
    Text(Copy.FriendRows.trend(trend.fraction) ?? "")
      .font(TollFont.captionNumber)
      .foregroundStyle(TollColor.label2)
  }
}

/// The one place row sentences are assembled, so every row reads in the same order
/// ("Adi, about usual, 3 passes today, down 23 percent on last week").
public enum AccessibilitySentence {
  public static func join(_ parts: [String?]) -> String {
    parts
      .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
      .joined(separator: ", ")
  }
}

/// The trailing column for rows at standard sizes, or the line beneath at accessibility sizes.
struct RowStack<Leading: View, Trailing: View>: View {
  let minHeight: CGFloat
  let leading: Leading
  let trailing: Trailing
  @Environment(\.dynamicTypeSize) private var typeSize

  init(
    minHeight: CGFloat, @ViewBuilder leading: () -> Leading,
    @ViewBuilder trailing: () -> Trailing
  ) {
    self.minHeight = minHeight
    self.leading = leading()
    self.trailing = trailing()
  }

  var body: some View {
    Group {
      if typeSize.isAccessibilitySize {
        VStack(alignment: .leading, spacing: 6) {
          leading
          trailing
        }
        .padding(.vertical, 10)
      } else {
        HStack(alignment: .center, spacing: TollSpacing.rowLeadingGap) {
          leading
          Spacer(minLength: TollSpacing.rowLeadingGap)
          trailing
        }
      }
    }
    .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
    .contentShape(Rectangle())
  }
}
