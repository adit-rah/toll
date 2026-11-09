import SwiftUI

/// Design §2.1 and §4.3. An 8 pt grid; the odd values are the ones the design names explicitly.
public enum TollSpacing {
  public static let grid: CGFloat = 8
  public static let gutter: CGFloat = 20
  public static let narrowGutter: CGFloat = 16
  public static let sectionGap: CGFloat = 32
  public static let cardPadding: CGFloat = 16
  public static let rowMinHeight: CGFloat = 52
  public static let friendRowMinHeight: CGFloat = 60
  public static let blockRowHeight: CGFloat = 64
  public static let compactBlockRowHeight: CGFloat = 48
  public static let minTapTarget: CGFloat = 44
  public static let heroTop: CGFloat = 12
  public static let heroToList: CGFloat = 36
  public static let barHeight: CGFloat = 44
  public static let titleGap: CGFloat = 28
  public static let waitCardTop: CGFloat = 180
  public static let rowLeadingSlot: CGFloat = 32
  public static let rowLeadingGap: CGFloat = 12

  /// 4.7" and 5.4" phones are 375 pt wide; everything wider gets the full gutter.
  public static func horizontalGutter(forWidth width: CGFloat) -> CGFloat {
    width <= 375 ? narrowGutter : gutter
  }
}

/// Design §2.4. Inner radii are the outer radius minus the padding between them.
public enum TollRadius {
  public static let card: CGFloat = 16
  public static let rowInCard: CGFloat = 12
  public static let sheet: CGFloat = 20
  public static let waitCard: CGFloat = 20
  public static let chip: CGFloat = 8
  public static let button: CGFloat = 12
  public static let field: CGFloat = 14
}

extension View {
  /// Horizontal gutter that narrows on small phones, measured from the width offered to the view.
  public func tollGutter() -> some View {
    modifier(GutterPadding())
  }
}

private struct GutterPadding: ViewModifier {
  @State private var width: CGFloat = 390

  func body(content: Content) -> some View {
    content
      .padding(.horizontal, TollSpacing.horizontalGutter(forWidth: width))
      .onGeometryChange(for: CGFloat.self) { proxy in
        proxy.size.width
      } action: { newWidth in
        width = newWidth
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
