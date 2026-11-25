import SwiftUI
import TollCore
import TollUI

/// The night behind the stars: the hour's gradient and glow, the Milky Way and the fixed dust
/// (`SkyDust`). Atmosphere only: none of it is a catalogue star, and nothing here moves.
struct SkyBackdrop: View {
  let light: SkyLight
  /// The dust and the band read as noise on a tile a few points wide.
  var atmosphere = true

  var body: some View {
    Canvas { context, size in
      let palette = SkyColor.palette(light)
      let whole = Path(CGRect(origin: .zero, size: size))
      context.fill(
        whole,
        with: .linearGradient(
          Gradient(stops: palette.stops), startPoint: CGPoint(x: size.width / 2, y: 0),
          endPoint: CGPoint(x: size.width / 2, y: size.height)))
      glow(palette, in: &context, size: size)
      guard atmosphere else { return }
      milkyWay(in: &context, size: size)
      for mote in SkyDust.motes {
        let r = mote.size
        context.fill(
          Path(
            ellipseIn: CGRect(
              x: mote.x * size.width - r, y: mote.y * size.height - r, width: r * 2, height: r * 2)),
          with: .color(SkyColor.dust.opacity(mote.brightness)))
      }
    }
  }

  /// A wide ellipse of light rising from the horizon's middle.
  private func glow(_ palette: SkyColor.Palette, in context: inout GraphicsContext, size: CGSize) {
    let radius = size.width * 0.8
    var layer = context
    layer.translateBy(x: size.width / 2, y: size.height)
    layer.scaleBy(x: 1, y: max(0.01, palette.glowReach * size.height / radius))
    layer.fill(
      Path(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2)),
      with: .radialGradient(
        Gradient(colors: [palette.glow, palette.glow.opacity(0)]), center: .zero, startRadius: 0,
        endRadius: radius))
  }

  /// The band as two blurred strokes, a wide faint one and a brighter core, along `SkyDust.band`.
  private func milkyWay(in context: inout GraphicsContext, size: CGSize) {
    let band = SkyDust.band
    var path = Path()
    path.move(to: CGPoint(x: band.from.x * size.width, y: band.from.y * size.height))
    path.addLine(to: CGPoint(x: band.to.x * size.width, y: band.to.y * size.height))
    let across = band.width * min(size.width, size.height)
    context.drawLayer { layer in
      layer.addFilter(.blur(radius: across * 0.45))
      layer.stroke(path, with: .color(SkyColor.dust.opacity(0.075)), lineWidth: across)
      layer.stroke(path, with: .color(SkyColor.dust.opacity(0.07)), lineWidth: across * 0.35)
    }
  }
}

/// The land under the sky: a low, gentle hill line in the page's own colour, so the page below
/// reads as the ground. A fainter ridge behind it gives depth. Fixed and abstract: no houses or trees.
struct SkyHorizon: View {
  var land = TollColor.bg

  var body: some View {
    ZStack {
      Hill(points: [(0, 0.34), (0.22, 0.16), (0.55, 0.02), (0.8, 0.2), (1, 0.12)])
        .fill(land.opacity(0.32))
      Hill(points: [(0, 0.62), (0.3, 0.3), (0.62, 0.7), (0.86, 0.5), (1, 0.56)])
        .fill(land)
    }
    .accessibilityHidden(true)
  }

  /// A smooth line through points (across, down; both 0 to 1), closed along the bottom.
  struct Hill: Shape {
    let points: [(CGFloat, CGFloat)]

    func path(in rect: CGRect) -> Path {
      let at = points.map {
        CGPoint(x: rect.minX + $0.0 * rect.width, y: rect.minY + $0.1 * rect.height)
      }
      var path = Path()
      guard let first = at.first else { return path }
      path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
      path.addLine(to: first)
      for index in 1..<at.count {
        // Catmull-Rom through the points, as cubic curves: soft, with no corners.
        let p0 = at[max(0, index - 2)]
        let p1 = at[index - 1]
        let p2 = at[index]
        let p3 = at[min(at.count - 1, index + 1)]
        path.addCurve(
          to: p2, control1: CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6),
          control2: CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6))
      }
      path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
      path.closeSubpath()
      return path
    }
  }
}

/// Last night's moon (`Moon`): the lit part on the right side for the night's place, a faint
/// earthshine on the rest, and a soft halo.
struct SkyMoon: View {
  let moon: Moon
  var radius: CGFloat = 11

  var body: some View {
    Canvas { context, size in
      let centre = CGPoint(x: size.width / 2, y: size.height / 2)
      let halo = radius * 3.2
      context.fill(
        Path(
          ellipseIn: CGRect(
            x: centre.x - halo, y: centre.y - halo, width: halo * 2, height: halo * 2)),
        with: .radialGradient(
          Gradient(colors: [
            SkyColor.moon.opacity(0.06 + 0.12 * moon.fraction), SkyColor.moon.opacity(0),
          ]), center: centre, startRadius: radius * 0.8, endRadius: halo))
      let disc = CGRect(
        x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2)
      context.fill(Path(ellipseIn: disc), with: .color(SkyColor.moon.opacity(0.1)))
      // A little darker toward the limb, as the real moon is.
      context.fill(
        lit(centre),
        with: .radialGradient(
          Gradient(colors: [SkyColor.moon, SkyColor.moon.opacity(0.82)]), center: centre,
          startRadius: 0, endRadius: radius))
    }
    .frame(width: radius * 7, height: radius * 7)
    .accessibilityHidden(true)
  }

  /// From the top, down the lit limb, and back up the terminator, an ellipse across the disc.
  private func lit(_ centre: CGPoint) -> Path {
    let side: CGFloat = moon.litOnRight ? 1 : -1
    let terminator = CGFloat(moon.terminator) * radius
    let steps = 48
    var path = Path()
    for step in 0...steps {
      let angle = CGFloat.pi * CGFloat(step) / CGFloat(steps)
      let point = CGPoint(
        x: centre.x + side * radius * sin(angle), y: centre.y - radius * cos(angle))
      if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
    }
    for step in stride(from: steps, through: 0, by: -1) {
      let angle = CGFloat.pi * CGFloat(step) / CGFloat(steps)
      path.addLine(
        to: CGPoint(
          x: centre.x + side * terminator * sin(angle), y: centre.y - radius * cos(angle)))
    }
    path.closeSubpath()
    return path
  }
}
