import SwiftUI
import TollCore
import TollUI
import UIKit

/// Your sky drawn (D79): lit stars sized by their real brightness, the lines between lit stars, and
/// the newest star in the accent. The night stays dark in both appearances, so it draws with the
/// dark tokens on the dark page colour. Nothing moves except the newest star's one crossfade
/// (design §2.5), which the owner drives with `newestShown`.
struct SkyCanvas: View {
  let drawing: Sky.Drawing
  var newestShown = true
  var corner: CGFloat = TollRadius.field
  /// Off when the owner sets the frame (a tile): the stars stay centred in it.
  var keepsAspect = true

  var body: some View {
    let bounds = drawing.bounds
    ZStack {
      Canvas { context, size in draw(in: &context, size: size, newest: false) }
      if drawing.newest != nil {
        Canvas { context, size in draw(in: &context, size: size, newest: true) }
          .opacity(newestShown ? 1 : 0)
      }
    }
    .aspectRatio(
      keepsAspect ? CGFloat(bounds.width / max(bounds.height, 0.001)) : nil, contentMode: .fit
    )
    .background(
      TollColor.bg, in: RoundedRectangle(cornerRadius: corner, style: .continuous)
    )
    .environment(\.colorScheme, .dark)
    .accessibilityHidden(true)
  }

  /// One layer: everything but the newest star and its lines, or only those.
  private func draw(in context: inout GraphicsContext, size: CGSize, newest: Bool) {
    let bounds = drawing.bounds
    let scale = min(size.width / bounds.width, size.height / bounds.height)
    let origin = CGPoint(
      x: (size.width - bounds.width * scale) / 2 - bounds.x * scale,
      y: (size.height - bounds.height * scale) / 2 - bounds.y * scale)
    // Star sizes are set for the whole sky about 313 points wide; closer in, they grow more slowly
    // than the sky does, as a nearer look would show them.
    let grow = min(1.5, max(0.8, (scale / 313).squareRoot()))
    func point(_ star: Sky.Star) -> CGPoint {
      CGPoint(x: origin.x + star.x * scale, y: origin.y + star.y * scale)
    }
    func radius(_ star: Sky.Star) -> CGFloat {
      let base = min(2.4, max(0.8, 1.9 - 0.25 * star.magnitude))
      return base * grow * min(1.6, 1 + 0.2 * CGFloat(star.times - 1))
    }

    for line in drawing.lines {
      let touchesNewest = line.from == drawing.newest || line.to == drawing.newest
      guard touchesNewest == newest else { continue }
      let a = drawing.stars[line.from]
      let b = drawing.stars[line.to]
      let pa = point(a)
      let pb = point(b)
      let length = hypot(pb.x - pa.x, pb.y - pa.y)
      // A small gap at each end, so lines lead to stars without touching them.
      let gapA = radius(a) + 2.5 * grow
      let gapB = radius(b) + 2.5 * grow
      guard length > gapA + gapB else { continue }
      let ux = (pb.x - pa.x) / length
      let uy = (pb.y - pa.y) / length
      var path = Path()
      path.move(to: CGPoint(x: pa.x + ux * gapA, y: pa.y + uy * gapA))
      path.addLine(to: CGPoint(x: pb.x - ux * gapB, y: pb.y - uy * gapB))
      context.stroke(path, with: .color(TollColor.label3), lineWidth: 0.75 * grow)
    }

    for (index, star) in drawing.stars.enumerated() where (index == drawing.newest) == newest {
      let center = point(star)
      // The newest star is never too faint to find, whatever its magnitude.
      let r = newest ? max(radius(star), 1.7 * grow) : radius(star)
      if newest {
        let glow = r + 2.5 * grow
        context.fill(
          Path(
            ellipseIn: CGRect(
              x: center.x - glow, y: center.y - glow, width: glow * 2, height: glow * 2)),
          with: .color(TollColor.accent.opacity(0.22)))
      }
      context.fill(
        Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
        with: .color(newest ? TollColor.accent : TollColor.label))
    }
  }
}

/// The picture a landmark shares (D79): the sky and the number, made on the phone. Nothing else.
struct SkyPicture: View {
  let sky: Sky.Drawing
  let number: String

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      SkyCanvas(drawing: sky, corner: 0)
      HStack(spacing: 10) {
        Image(symbol: .sleep).font(.system(size: 20, weight: .medium))
          .foregroundStyle(TollColor.accent)
        Text(number).tollType(.sheetTitle, TollColor.label)
      }
    }
    .padding(28)
    .frame(width: 390)
    .background(TollColor.bg)
    .environment(\.colorScheme, .dark)
    .environment(\.dynamicTypeSize, .large)
  }
}

/// Shares the landmark's picture through the system share sheet, once it's made. The picture is
/// drawn here on the phone; nothing leaves unless the person sends it.
struct SkyShare: View {
  let landmark: Sky.Landmark
  @State private var picture: Image?

  var body: some View {
    Color.clear
      .frame(width: TollSpacing.minTapTarget, height: TollSpacing.minTapTarget)
      .overlay {
        if let picture {
          ShareLink(
            item: picture, preview: SharePreview(Copy.Sky.title, image: picture)
          ) {
            Image(symbol: .share).unredacted()
              .font(.system(size: 17, weight: .medium))
              .foregroundStyle(TollColor.accent)
              .frame(minWidth: TollSpacing.minTapTarget, minHeight: TollSpacing.minTapTarget)
          }
          .accessibilityLabel(Copy.Sky.share)
        }
      }
      .task(id: landmark) { picture = render() }
  }

  private func render() -> Image? {
    let renderer = ImageRenderer(
      content: SkyPicture(sky: landmark.sky, number: landmark.number))
    renderer.scale = 3
    return renderer.uiImage.map { Image(uiImage: $0) }
  }
}
