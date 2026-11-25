import SwiftUI

/// Diagonal stripes, for the buffers around sleep (#144): the time apps are locked while the person
/// is awake reads apart from sleep's solid bar by texture, not colour, at any width.
public struct Hatch: Shape {
  let spacing: CGFloat

  public init(spacing: CGFloat = 4) {
    self.spacing = spacing
  }

  public func path(in rect: CGRect) -> Path {
    var path = Path()
    var x = rect.minX - rect.height
    while x < rect.maxX {
      path.move(to: CGPoint(x: x, y: rect.maxY))
      path.addLine(to: CGPoint(x: x + rect.height, y: rect.minY))
      x += spacing
    }
    return path
  }
}

/// A buffer segment: its fill with stripes cut across it, clipped to its corners.
public struct HatchedBar: View {
  let fill: Color
  let stripes: Color
  let radius: CGFloat

  public init(fill: Color, stripes: Color, radius: CGFloat) {
    self.fill = fill
    self.stripes = stripes
    self.radius = radius
  }

  public var body: some View {
    let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
    shape.fill(fill)
      .overlay(Hatch().stroke(stripes, lineWidth: 1.5).clipShape(shape))
      .accessibilityHidden(true)
  }
}
