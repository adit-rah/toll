import SwiftUI
import TollCore
import UIKit

/// The design canvas's type scale (sticky note s1): SF Pro at the boards' sizes, weights and line
/// heights, with no extra letter spacing. Each size scales with Dynamic Type from the text style it
/// sits nearest, so 16 pt grows like Callout and 30 pt like Large Title.
public struct TollType: Sendable, Equatable {
  public var size: CGFloat
  public var lineHeight: CGFloat
  public var weight: Font.Weight
  public var style: Font.TextStyle
  /// Points between letters at the default size; only the uppercase eyebrows use it.
  public var tracking: CGFloat = 0
  public var uppercase = false
  public var tabular = false

  public init(
    size: CGFloat, lineHeight: CGFloat, weight: Font.Weight, style: Font.TextStyle,
    tracking: CGFloat = 0, uppercase: Bool = false, tabular: Bool = false
  ) {
    self.size = size
    self.lineHeight = lineHeight
    self.weight = weight
    self.style = style
    self.tracking = tracking
    self.uppercase = uppercase
    self.tabular = tabular
  }

  /// Welcome's title: 40/47 semibold.
  public static let display = TollType(
    size: 40, lineHeight: 47, weight: .semibold, style: .largeTitle)
  /// Setup titles: 32/38 semibold, 28 pt under the bar.
  public static let setupTitle = TollType(
    size: 32, lineHeight: 38, weight: .semibold, style: .largeTitle)
  /// Pushed screens' titles: 30/35 semibold, 8 pt under the bar.
  public static let screenTitle = TollType(
    size: 30, lineHeight: 35, weight: .semibold, style: .largeTitle)
  /// Sheet titles: 24/28 semibold.
  public static let sheetTitle = TollType(
    size: 24, lineHeight: 28, weight: .semibold, style: .title2)
  /// The numbers in This week and Your free week: 22/28 semibold.
  public static let stat = TollType(
    size: 22, lineHeight: 28, weight: .semibold, style: .title2, tabular: true)
  /// Welcome's line under the title: 18/26.
  public static let lead = TollType(size: 18, lineHeight: 26, weight: .regular, style: .body)
  /// Buttons: 17 semibold.
  public static let button = TollType(size: 17, lineHeight: 22, weight: .semibold, style: .body)
  /// The back button and other bar text: 17 regular.
  public static let bar = TollType(size: 17, lineHeight: 22, weight: .regular, style: .body)
  /// A row's title: 16/21 medium.
  public static let rowTitle = TollType(size: 16, lineHeight: 21, weight: .medium, style: .callout)
  /// A sheet's sentence: 16/23.
  public static let sheetBody = TollType(
    size: 16, lineHeight: 23, weight: .regular, style: .callout)
  /// Lines under titles and heroes: 15/21.
  public static let body = TollType(size: 15, lineHeight: 21, weight: .regular, style: .subheadline)
  /// The hero's line: 15/20, numbers tabular.
  public static let heroLine = TollType(
    size: 15, lineHeight: 20, weight: .regular, style: .subheadline, tabular: true)
  /// Text links under heroes and in sheets: 15 semibold.
  public static let link = TollType(
    size: 15, lineHeight: 20, weight: .semibold, style: .subheadline)
  /// Quiet secondary actions: 15 medium.
  public static let quiet = TollType(size: 15, lineHeight: 20, weight: .medium, style: .subheadline)
  /// Notes in cards: 14/19.
  public static let note = TollType(size: 14, lineHeight: 19, weight: .regular, style: .subheadline)
  /// Section actions ("See all", "New"): 14 semibold.
  public static let action = TollType(
    size: 14, lineHeight: 19, weight: .semibold, style: .subheadline)
  /// Welcome's restore link: 14 medium.
  public static let smallQuiet = TollType(
    size: 14, lineHeight: 19, weight: .medium, style: .subheadline)
  /// A row's second line and footnotes: 13/18.
  public static let detail = TollType(
    size: 13, lineHeight: 18, weight: .regular, style: .footnote, tabular: true)
  /// A row's trailing word ("On now", "Mon"): 13 semibold.
  public static let trailing = TollType(
    size: 13, lineHeight: 18, weight: .semibold, style: .footnote)
  /// Section headers: 12/16 semibold, uppercase, 0.8 pt apart.
  public static let eyebrow = TollType(
    size: 12, lineHeight: 16, weight: .semibold, style: .caption, tracking: 0.8, uppercase: true)
  /// Labels under stats: 12/16.
  public static let caption = TollType(size: 12, lineHeight: 16, weight: .regular, style: .caption)
  /// Chart labels: 11/14 medium.
  public static let micro = TollType(size: 11, lineHeight: 14, weight: .medium, style: .caption2)
  /// Chart values: 11/14, tabular.
  public static let microNumber = TollType(
    size: 11, lineHeight: 14, weight: .regular, style: .caption2, tabular: true)
  /// A chart's own heading: 11 semibold uppercase, 0.8 pt apart.
  public static let microEyebrow = TollType(
    size: 11, lineHeight: 14, weight: .semibold, style: .caption2, tracking: 0.8, uppercase: true)
  /// Home's big time: 64/70 semibold, tabular. Capped at AX2 by `HeroTime`.
  public static let hero = TollType(
    size: 64, lineHeight: 70, weight: .semibold, style: .largeTitle, tabular: true)
  /// The am/pm beside the big time: 24 medium.
  public static let heroSuffix = TollType(
    size: 24, lineHeight: 28, weight: .medium, style: .largeTitle)

  /// The font at a Dynamic Type size, scaled the way its text style scales.
  public func font(at typeSize: DynamicTypeSize) -> Font {
    let scaled = scale(at: typeSize) * size
    let font = Font.system(size: scaled, weight: weight)
    return tabular ? font.monospacedDigit() : font
  }

  /// How much this style grows at `typeSize` relative to the default (Large).
  public func scale(at typeSize: DynamicTypeSize) -> CGFloat {
    let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(typeSize))
    return UIFontMetrics(forTextStyle: style.uiStyle).scaledValue(for: size, compatibleWith: traits)
      / size
  }

  /// The board's leading beyond what SF Pro sets by itself at this size.
  func extraLeading(at typeSize: DynamicTypeSize) -> CGFloat {
    let scale = scale(at: typeSize)
    let natural = UIFont.systemFont(ofSize: size * scale, weight: weight.uiWeight).lineHeight
    return max(0, lineHeight * scale - natural)
  }
}

extension View {
  /// Sets a canvas type style: font, line height (half the extra leading above the first line and
  /// half below the last, as CSS does), letter spacing and case.
  public func tollType(_ type: TollType) -> some View {
    modifier(TollTypeModifier(type: type))
  }

  /// A type style and the colour it is drawn in.
  public func tollType(_ type: TollType, _ color: Color) -> some View {
    tollType(type).foregroundStyle(color)
  }
}

extension EnvironmentValues {
  /// The wordless test (docs/design.md §5): every styled line drawn as a placeholder bar, so a screen
  /// can be judged by its shapes, symbols, colour and layout alone. Set only by demo renders.
  @Entry public var tollWordless = false
}

private struct TollTypeModifier: ViewModifier {
  let type: TollType
  @Environment(\.dynamicTypeSize) private var typeSize
  @Environment(\.tollWordless) private var wordless

  func body(content: Content) -> some View {
    let leading = type.extraLeading(at: typeSize)
    content
      .font(type.font(at: typeSize))
      .tracking(type.tracking)
      .textCase(type.uppercase ? .uppercase : nil)
      .lineSpacing(leading)
      .padding(.vertical, leading / 2)
      .redacted(reason: wordless ? .placeholder : [])
  }
}

extension Font.TextStyle {
  var uiStyle: UIFont.TextStyle {
    switch self {
    case .largeTitle: .largeTitle
    case .title: .title1
    case .title2: .title2
    case .title3: .title3
    case .headline: .headline
    case .subheadline: .subheadline
    case .callout: .callout
    case .footnote: .footnote
    case .caption: .caption1
    case .caption2: .caption2
    default: .body
    }
  }
}

extension Font.Weight {
  var uiWeight: UIFont.Weight {
    switch self {
    case .medium: .medium
    case .semibold: .semibold
    case .bold: .bold
    default: .regular
    }
  }
}

/// Home's big time, "10:30" with a small "pm" (the canvas): 64 pt, capped at AX2 so it never pushes
/// the rest of the hero off screen.
public struct HeroTime: View {
  let date: Date

  public init(_ date: Date) {
    self.date = date
  }

  public var body: some View {
    HeroTimeBody(date: date).dynamicTypeSize(...DynamicTypeSize.accessibility2)
  }
}

private struct HeroTimeBody: View {
  let date: Date

  var body: some View {
    let parts = HeroTimeParts(date: date)
    HStack(alignment: .firstTextBaseline, spacing: 6) {
      Text(parts.time)
        .tollType(.hero, TollColor.label)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .contentTransition(.numericText())
        .animation(Motion.movement, value: parts.time)
      if let suffix = parts.suffix {
        Text(suffix).tollType(.heroSuffix, TollColor.label2)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Copy.time(date))
  }
}

/// The phone's own time ("10:30 pm" or "22:30", `Copy.time`), split into the numbers and the day
/// period so the period can be set small. 24-hour phones get no suffix.
struct HeroTimeParts {
  let time: String
  let suffix: String?

  init(date: Date) {
    let parts = Copy.time(date).split(maxSplits: 1, whereSeparator: \.isWhitespace).map(String.init)
    time = parts.first ?? ""
    suffix = parts.count > 1 ? parts[1] : nil
  }
}
