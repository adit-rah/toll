import SwiftUI

/// The design canvas's spacing. Named for where the boards use them; nothing else holds a gap.
public enum TollSpacing {
  public static let gutter: CGFloat = 24
  /// 4.7" and 5.4" phones are 375 pt wide and get the narrow gutter.
  public static let narrowGutter: CGFloat = 16
  /// The bar above every title: back button, progress or the settings gear.
  public static let barHeight: CGFloat = 44
  /// A setup title sits 28 pt under the bar; a pushed screen's title 8 pt.
  public static let setupTitleGap: CGFloat = 28
  public static let pushedTitleGap: CGFloat = 8
  /// From a pushed screen's title to its first card.
  public static let titleToContent: CGFloat = 20
  /// From a setup title to its line, and from that line to the content.
  public static let titleToLine: CGFloat = 12
  public static let lineToContent: CGFloat = 28
  /// A card's sides.
  public static let cardPadding: CGFloat = 16
  /// A note card's top and bottom (14 16 on the boards).
  public static let noteCardVertical: CGFloat = 14
  /// The stats card's top and bottom (18 16).
  public static let statsCardVertical: CGFloat = 18
  /// From a card to the count or footnote under it.
  public static let underCard: CGFloat = 10
  /// Between the leading tile and a row's text.
  public static let rowGap: CGFloat = 14
  /// From a section header to its card.
  public static let headerToCard: CGFloat = 10
  public static let minTapTarget: CGFloat = 44
  /// Above the main button when something sits over it (a footnote or a quiet link).
  public static let aboveButton: CGFloat = 14
  /// Phones without a home indicator keep this much under the main button.
  public static let bottomWithoutIndicator: CGFloat = 16

  public static func horizontalGutter(forWidth width: CGFloat) -> CGFloat {
    width <= 375 ? narrowGutter : gutter
  }
}

/// The canvas's radii.
public enum TollRadius {
  public static let card: CGFloat = 18
  public static let button: CGFloat = 16
  /// Search fields and the map's inner shapes.
  public static let field: CGFloat = 12
  /// Chart bars.
  public static let chartBar: CGFloat = 6
}

/// A canvas row's height and the tile that leads it.
public struct RowSize: Sendable, Equatable {
  public var minHeight: CGFloat
  public var tile: TileSize

  public init(minHeight: CGFloat, tile: TileSize) {
    self.minHeight = minHeight
    self.tile = tile
  }

  /// 60 pt, 36 pt tile: editors, Ready, Settings.
  public static let regular = RowSize(minHeight: 60, tile: .row)
  /// 58 pt: Home's block list, a toggle row.
  public static let list = RowSize(minHeight: 58, tile: .row)
  /// 62 pt: a night's hours with "Change".
  public static let night = RowSize(minHeight: 62, tile: .row)
  /// 64 pt: the home place under the map.
  public static let place = RowSize(minHeight: 64, tile: .row)
  /// 76 pt, 44 pt tile: the permissions list.
  public static let permission = RowSize(minHeight: 76, tile: .permission)
  /// 56 pt, 32 pt tile: a whole category in an apps list.
  public static let category = RowSize(minHeight: 56, tile: .small)
  /// 52 pt, 32 pt tile: an app or a site in an apps list.
  public static let compact = RowSize(minHeight: 52, tile: .small)
}

/// The canvas's icon tiles: the box, its corners and the symbol inside.
public enum TileSize: Sendable, Equatable {
  /// 32 pt, 8 pt corners, 18 pt symbol.
  case small
  /// 36 pt, 10 pt corners, 20 pt symbol.
  case row
  /// 40 pt, 11 pt corners, 22 pt symbol: Welcome's offer card.
  case large
  /// 44 pt, 12 pt corners, 24 pt symbol: the permissions list.
  case permission
  /// 48 pt, 13 pt corners, 26 pt symbol: a sheet's leading icon.
  case sheet

  public var side: CGFloat {
    switch self {
    case .small: 32
    case .row: 36
    case .large: 40
    case .permission: 44
    case .sheet: 48
    }
  }

  public var radius: CGFloat {
    switch self {
    case .small: 8
    case .row: 10
    case .large: 11
    case .permission: 12
    case .sheet: 13
    }
  }

  /// SF Symbols draw about a tenth inside their point size; this matches the boards' 24-unit icons.
  public var symbol: CGFloat {
    switch self {
    case .small: 16
    case .row: 18
    case .large: 20
    case .permission: 21
    case .sheet: 23
    }
  }
}

extension View {
  /// Horizontal gutter that narrows on small phones, measured from the width offered to the view.
  public func tollGutter() -> some View {
    modifier(GutterPadding())
  }
}

private struct GutterPadding: ViewModifier {
  func body(content: Content) -> some View {
    GutterLayout { content }
  }
}

/// A layout rather than state fed by a geometry reader: the gutter is right on the first frame, so
/// nothing shifts 4 pt after appearing on a narrow phone and no screen lays out twice.
private struct GutterLayout: Layout {
  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let gutter = TollSpacing.horizontalGutter(forWidth: proposal.width ?? .infinity)
    let inner = ProposedViewSize(
      width: proposal.width.map { max(0, $0 - 2 * gutter) }, height: proposal.height)
    var size = CGSize.zero
    for subview in subviews {
      let fit = subview.sizeThatFits(inner)
      size.width = max(size.width, fit.width)
      size.height = max(size.height, fit.height)
    }
    return CGSize(width: size.width + 2 * gutter, height: size.height)
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    let gutter = TollSpacing.horizontalGutter(forWidth: bounds.width)
    let inner = ProposedViewSize(width: max(0, bounds.width - 2 * gutter), height: bounds.height)
    for subview in subviews {
      subview.place(
        at: CGPoint(x: bounds.midX, y: bounds.midY), anchor: .center, proposal: inner)
    }
  }
}

/// A one-pixel separator in `separator`.
public struct Hairline: View {
  @Environment(\.displayScale) private var displayScale

  public init() {}

  public var body: some View {
    Rectangle()
      .fill(TollColor.separator)
      .frame(height: 1 / displayScale)
      .accessibilityHidden(true)
  }
}
