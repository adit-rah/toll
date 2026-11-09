import SwiftUI

/// Design §2.2. Dynamic Type styles only, so every size follows the user's text setting.
public enum TollFont {
  public static let title = Font.title2.weight(.semibold)
  public static let headline = Font.headline
  public static let body = Font.body
  public static let bodyMedium = Font.body.weight(.medium)
  public static let number = Font.body.weight(.medium).monospacedDigit()
  public static let subhead = Font.subheadline
  public static let subheadMedium = Font.subheadline.weight(.medium)
  public static let subheadSemibold = Font.subheadline.weight(.semibold)
  public static let caption = Font.footnote
  public static let captionMedium = Font.footnote.weight(.medium)
  public static let captionNumber = Font.footnote.monospacedDigit()
  public static let micro = Font.caption2.weight(.medium)
  /// Friend row detail line: 12 pt, between `caption` and `micro` (design §3.4).
  public static let detail = Font.caption
  /// Setup and sign-in titles: 34 pt semibold (design §4.3).
  public static let screenTitle = Font.largeTitle.weight(.semibold)
}

/// A type token with the label tier the design pairs it with.
public enum TollText: Sendable {
  case title, headline, body, bodyMedium, number, subhead, caption, micro, detail

  public var font: Font {
    switch self {
    case .title: TollFont.title
    case .headline: TollFont.headline
    case .body: TollFont.body
    case .bodyMedium: TollFont.bodyMedium
    case .number: TollFont.number
    case .subhead: TollFont.subhead
    case .caption: TollFont.caption
    case .micro: TollFont.micro
    case .detail: TollFont.detail
    }
  }

  public var color: Color {
    switch self {
    case .title, .headline, .body, .bodyMedium, .number: TollColor.label
    case .subhead, .caption, .detail: TollColor.label2
    case .micro: TollColor.label3
    }
  }
}

extension View {
  public func tollText(_ token: TollText) -> some View {
    font(token.font).foregroundStyle(token.color)
  }
}

/// The `hero` numeral: 72 pt rounded semibold with tabular digits, scaled with Dynamic Type and capped
/// at AX2 so it never pushes the rest of the hero zone off screen.
public struct HeroNumber: View {
  let text: String
  let size: CGFloat
  let countsDown: Bool

  public init(_ text: String, size: CGFloat = 72, countsDown: Bool = false) {
    self.text = text
    self.size = size
    self.countsDown = countsDown
  }

  public var body: some View {
    ScaledHeroText(text: text, base: size, countsDown: countsDown)
      .dynamicTypeSize(...DynamicTypeSize.accessibility2)
  }
}

// A separate view so `@ScaledMetric` reads the capped dynamic type size set above it.
private struct ScaledHeroText: View {
  let text: String
  let countsDown: Bool
  @ScaledMetric private var size: CGFloat

  init(text: String, base: CGFloat, countsDown: Bool) {
    self.text = text
    self.countsDown = countsDown
    _size = ScaledMetric(wrappedValue: base, relativeTo: .largeTitle)
  }

  var body: some View {
    Text(text)
      .font(.system(size: size, weight: .semibold, design: .rounded).monospacedDigit())
      .tracking(-2.5 * size / 72)
      .lineLimit(1)
      .minimumScaleFactor(0.5)
      .contentTransition(.numericText(countsDown: countsDown))
      .animation(Motion.movement, value: text)
  }
}
