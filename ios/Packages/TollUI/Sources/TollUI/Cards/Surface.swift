import SwiftUI

extension View {
  /// A card's ground: `surface`, edged with a one-pixel `separator`. In light the card is no
  /// brighter than the page, so the hairline, not glare, sets it apart (design §2.3).
  public func tollSurface<S: InsettableShape>(_ shape: S, fill: Color = TollColor.surface)
    -> some View
  {
    modifier(SurfaceGround(shape: shape, fill: fill))
  }

  /// The card's shape at the canvas's radius.
  public func tollSurface(fill: Color = TollColor.surface) -> some View {
    tollSurface(RoundedRectangle(cornerRadius: TollRadius.card, style: .continuous), fill: fill)
  }
}

private struct SurfaceGround<S: InsettableShape>: ViewModifier {
  let shape: S
  let fill: Color
  @Environment(\.displayScale) private var scale

  func body(content: Content) -> some View {
    content
      .background(fill, in: shape)
      .overlay(shape.strokeBorder(TollColor.separator, lineWidth: 1 / scale))
  }
}
