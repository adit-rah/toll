import SwiftUI
import TollCore
import TollUI

/// Your sky's lit stars (D79): sized by real magnitude with a soft halo, tinted by their real B–V,
/// joined by thin lines that stop short of each disc, and the names of completed figures set beside
/// them like a chart. Names and lines are faint; a figure a tap brought forward (`SkyFocus`) is
/// drawn bright over its faint self and crossfades in 200 ms (design §2.5). The newest star and its
/// lines are drawn apart (`SkyNewest`), so they can arrive once. Nothing here moves on its own.
struct SkyStarsLayer: View {
  let drawing: Sky.Drawing
  let layout: SkyLayout
  var names = true
  /// The figures drawn bright.
  var bright: Set<Constellation> = []
  /// The land's height at the bottom, which names keep above.
  var ground: CGFloat = 0
  @Environment(\.tollWordless) private var wordless

  var body: some View {
    ZStack {
      Canvas { context, size in
        draw(nil, line: SkyColor.line, name: SkyColor.line, in: &context, size: size)
      }
      // One layer per figure, so each brightens or fades on its own.
      ForEach(figures, id: \.self) { figure in
        Canvas { context, size in
          draw(
            figure, line: SkyColor.lineBright, name: SkyColor.nameBright, in: &context, size: size)
        }
        .opacity(bright.contains(figure) ? 1 : 0)
      }
      Canvas { context, _ in
        let style = SkyStarStyle(layout: layout)
        for (index, star) in drawing.stars.enumerated() where index != drawing.newest {
          style.draw(star, colour: SkyColor.star(bv: star.bv), in: &context)
        }
      }
    }
    .animation(Motion.stateChange, value: bright)
  }

  /// The figures with a line or a name to brighten, in the drawing's order.
  private var figures: [Constellation] {
    var seen = Set<Constellation>()
    return (drawing.lines.map(\.constellation) + drawing.names.map(\.constellation))
      .filter { seen.insert($0).inserted }
  }

  /// The lines and names of one figure, or of every figure when `figure` is nil.
  private func draw(
    _ figure: Constellation?, line lineColour: Color, name nameColour: Color,
    in context: inout GraphicsContext, size: CGSize
  ) {
    let style = SkyStarStyle(layout: layout)
    for line in drawing.lines
    where !touchesNewest(line) && (figure == nil || line.constellation == figure) {
      if let path = style.line(drawing.stars[line.from], drawing.stars[line.to]) {
        context.stroke(path, with: .color(lineColour), lineWidth: style.lineWidth)
      }
    }
    guard names else { return }
    for (name, spot) in spots(style: style, in: context, size: size)
    where figure == nil || name.constellation == figure {
      if wordless {
        let bar = CGRect(x: spot.minX, y: spot.midY - 2.5, width: spot.width, height: 5)
        context.fill(Path(roundedRect: bar, cornerRadius: 2.5), with: .color(nameColour))
      } else {
        context.draw(
          context.resolve(text(name, colour: nameColour)),
          at: CGPoint(x: spot.midX, y: spot.midY), anchor: .center)
      }
    }
  }

  private func touchesNewest(_ line: Sky.Line) -> Bool {
    line.from == drawing.newest || line.to == drawing.newest
  }

  private func text(_ name: Sky.Name, colour: Color) -> Text {
    Text(name.text.uppercased())
      .font(.system(size: 9, weight: .medium))
      .tracking(1.4)
      .foregroundStyle(colour)
  }

  /// Where each name sits: small, spaced capitals 8 pt past the figure's edge star, inside the sky
  /// and above the land. A name takes its clearer side, else the other; where both would cover a
  /// name already set or a lit star, it is left off, as a chart declutters (VoiceOver still hears
  /// every name). Faint and bright place alike, so a bright name lands on its faint self. Wordless
  /// renders draw a bar the name's size instead (design §5).
  private func spots(style: SkyStarStyle, in context: GraphicsContext, size: CGSize)
    -> [(Sky.Name, CGRect)]
  {
    var placed: [(Sky.Name, CGRect)] = []
    for name in drawing.names {
      let measured = context.resolve(text(name, colour: SkyColor.line))
        .measure(in: CGSize(width: 300, height: 40))
      let x = min(
        max(layout.x(name.x), measured.width / 2 + 6), size.width - measured.width / 2 - 6)
      func rect(above: Bool) -> CGRect {
        let edge = layout.y(above ? name.top : name.bottom)
        let y = edge + (above ? -1 : 1) * (8 + measured.height / 2)
        return CGRect(
          x: x - measured.width / 2, y: y - measured.height / 2, width: measured.width,
          height: measured.height)
      }
      func clear(_ candidate: CGRect) -> Bool {
        let room = candidate.insetBy(dx: -4, dy: -2)
        return candidate.minY > 0 && candidate.maxY < size.height - ground
          && !placed.contains { $0.1.intersects(room) }
          && !drawing.stars.contains { room.contains(style.point($0)) }
      }
      if let spot = [rect(above: name.above), rect(above: !name.above)].first(where: clear) {
        placed.append((name, spot))
      }
    }
    return placed
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
  /// The figures a tap brought forward (`SkyFocus`); the new lines brighten with theirs.
  var bright: Set<Constellation> = []

  var body: some View {
    if let newest = drawing.newest {
      let style = SkyStarStyle(layout: layout)
      let mark = drawing.stars[newest]
      ZStack {
        ForEach(Array(drawing.lines.enumerated()), id: \.offset) { _, line in
          if line.from == newest || line.to == newest {
            let other = drawing.stars[line.from == newest ? line.to : line.from]
            // From the star it joins toward the new one, so the trim draws outward to it.
            let segment = Segment(path: style.line(other, mark)).trim(from: 0, to: lines)
            ZStack {
              segment.stroke(SkyColor.line, lineWidth: style.lineWidth)
              segment.stroke(SkyColor.lineBright, lineWidth: style.lineWidth)
                .opacity(bright.contains(line.constellation) ? 1 : 0)
                .animation(Motion.stateChange, value: bright)
            }
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
