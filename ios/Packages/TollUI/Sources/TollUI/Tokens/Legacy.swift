import SwiftUI

// The names screens used before the canvas's type scale and spacing (S19). Each screen moves to
// `TollType` and the canvas spacing as it is rebuilt; the last step of the stack deletes this file.

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
  public static let detail = Font.caption
  public static let sheetTitle = Font.title3.weight(.semibold)
  public static let screenTitle = Font.largeTitle.weight(.semibold)
}

extension TollSpacing {
  public static let grid: CGFloat = 8
  public static let sectionGap: CGFloat = 32
  public static let rowMinHeight: CGFloat = 52
  public static let titleGap: CGFloat = 28
  public static let groupGap: CGFloat = 24
  public static let labelGap: CGFloat = 8
  public static let footerBottom: CGFloat = 12
  public static let rowLeadingGap: CGFloat = 12
}

extension TollRadius {
  public static let rowInCard: CGFloat = 12
  public static let sheet: CGFloat = 20
  public static let chip: CGFloat = 8
}

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
