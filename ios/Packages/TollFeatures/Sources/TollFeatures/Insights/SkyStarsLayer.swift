import SwiftUI
import TollCore
import TollUI

/// Your sky's lit stars (D79): sized by real magnitude with a soft halo, tinted by their real B–V,
/// joined by thin lines that stop short of each disc, and the names of completed figures set beside
/// them like a chart. The newest star and its lines are drawn apart (`SkyNewest`), so they can
/// arrive once. Drawn once; nothing here moves.
struct SkyStarsLayer: View {
  let drawing: Sky.Drawing
  let layout: SkyLayout
  var names = true
  @Environment(\.tollWordless) private var wordless

  var body: some View {
    Canvas { context, size in
      let style = SkyStarStyle(layout: layout)
      for line in drawing.lines where !touchesNewest(line) {
        if let path = style.line(drawing.stars[line.from], drawing.stars[line.to]) {
          context.stroke(path, with: .color(SkyColor.line), lineWidth: style.lineWidth)
        }
      }
      for (index, star) in drawing.stars.enumerated() where index != drawing.newest {
        style.draw(star, colour: SkyColor.star(bv: star.bv), in: &context)
      }
      guard names else { return }
      for name in drawing.names {
        drawName(name, style: style, in: &context, size: size)
      }
    }
  }

  private func touchesNewest(_ line: Sky.Line) -> Bool {
    line.from == drawing.newest || line.to == drawing.newest
  }

  /// Small, spaced capitals in `label3`, 10 pt past the figure's edge star, kept inside the sky.
  /// Wordless renders draw a bar the name's size instead (design §5).
  private func drawName(
    _ name: Sky.Name, style: SkyStarStyle, in context: inout GraphicsContext, size: CGSize
  ) {
    let text = Text(name.text.uppercased())
      .font(.system(size: 8.5, weight: .medium))
      .tracking(1.4)
      .foregroundStyle(SkyColor.line)
    let resolved = context.resolve(text)
    let measured = resolved.measure(in: CGSize(width: 300, height: 40))
    let x = min(
      max(layout.x(name.x), measured.width / 2 + 6), size.width - measured.width / 2 - 6)
    let y = layout.y(name.y) + (name.above ? -1 : 1) * (8 + measured.height / 2)
    if wordless {
      let bar = CGRect(
        x: x - measured.width / 2, y: y - 2.5, width: measured.width, height: 5)
      context.fill(Path(roundedRect: bar, cornerRadius: 2.5), with: .color(SkyColor.line))
    } else {
      context.draw(resolved, at: CGPoint(x: x, y: y), anchor: .center)
    }
  }
}

/// How stars and lines are drawn at a layout's scale, shared by the sky and its newest star.
struct SkyStarStyle {
  let layout: SkyLayout

  /// Sizes are set for the whole sky about 313 points wide; closer in, they grow more slowly than
  /// the sky does, as a nearer look would show them.
  var grow: CGFloat { min(1.5, max(0.75, CGFloat((layout.scale / 313).squareRoot()))) }
  var lineWidth: CGFloat { 0.7 * grow }

  func point(_ star: Sky.Star) -> CGPoint {
    CGPoint(x: layout.x(star.x), y: layout.y(star.y))
  }

  /// Brighter stars are larger, a little more each pass past the table.
  func radius(_ star: Sky.Star) -> CGFloat {
    let base = min(2.6, max(0.75, 2.05 - 0.3 * CGFloat(star.magnitude)))
    return base * grow * min(1.45, 1 + 0.15 * CGFloat(star.times - 1))
  }

  /// A line between two stars that stops short of each disc; nil when they are too close for one.
  func line(_ a: Sky.Star, _ b: Sky.Star) -> Path? {
    let pa = point(a)
    let pb = point(b)
    let length = hypot(pb.x - pa.x, pb.y - pa.y)
    let gapA = radius(a) + 3 * grow
    let gapB = radius(b) + 3 * grow
    guard length > gapA + gapB else { return nil }
    let ux = (pb.x - pa.x) / length
    let uy = (pb.y - pa.y) / length
    var path = Path()
    path.move(to: CGPoint(x: pa.x + ux * gapA, y: pa.y + uy * gapA))
    path.addLine(to: CGPoint(x: pb.x - ux * gapB, y: pb.y - uy * gapB))
    return path
  }

  /// A soft halo (a radial gradient of the star's own colour), then its disc.
  func draw(_ star: Sky.Star, colour: Color, in context: inout GraphicsContext, glow: CGFloat = 0.3)
  {
    let centre = point(star)
    let r = radius(star)
    let halo = r * 4.2
    context.fill(
      Path(
        ellipseIn: CGRect(x: centre.x - halo, y: centre.y - halo, width: halo * 2, height: halo * 2)
      ),
      with: .radialGradient(
        Gradient(colors: [colour.opacity(glow), colour.opacity(0)]), center: centre,
        startRadius: r * 0.5, endRadius: halo))
    context.fill(
      Path(ellipseIn: CGRect(x: centre.x - r, y: centre.y - r, width: r * 2, height: r * 2)),
      with: .color(colour))
  }
}

/// The newest star in the accent with its glow, and the lines it adds. It arrives once (design
/// §2.5): the star brightens from nothing over 450 ms, then each new line draws from the star it
/// joins over 450 ms; with Reduce Motion both crossfade in 200 ms. The owner drives `star` and
/// `lines` (0 to 1) and `linesShown`.
struct SkyNewest: View {
  let drawing: Sky.Drawing
  let layout: SkyLayout
  var star: CGFloat = 1
  var lines: CGFloat = 1
  var linesShown: CGFloat = 1

  var body: some View {
    if let newest = drawing.newest {
      let style = SkyStarStyle(layout: layout)
      let mark = drawing.stars[newest]
      ZStack {
        ForEach(Array(drawing.lines.enumerated()), id: \.offset) { _, line in
          if line.from == newest || line.to == newest {
            let other = drawing.stars[line.from == newest ? line.to : line.from]
            // From the star it joins toward the new one, so the trim draws outward to it.
            Segment(path: style.line(other, mark))
              .trim(from: 0, to: lines)
              .stroke(SkyColor.line, lineWidth: style.lineWidth)
              .opacity(linesShown)
          }
        }
        Canvas { context, _ in
          var bright = mark
          // Never too faint to find, whatever its magnitude.
          bright.magnitude = min(bright.magnitude, 1.2)
          style.draw(bright, colour: SkyColor.newest, in: &context, glow: 0.55)
        }
        .opacity(star)
      }
      .allowsHitTesting(false)
    }
  }

  private struct Segment: Shape {
    let path: Path?
    func path(in rect: CGRect) -> Path { path ?? Path() }
  }
}
