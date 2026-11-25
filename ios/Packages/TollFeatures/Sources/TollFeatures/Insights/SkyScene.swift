import SwiftUI
import TollCore
import TollUI

/// Your sky drawn whole, the one renderer for Your sleep, the landmark tile and the shared picture:
/// the hour's night, the dust and the Milky Way, the moon, the lit stars inside their field, and the
/// land under it. The sky is the same night in both appearances; only the land (`land`, the page's
/// colour) follows light or dark.
struct SkyScene: View {
  let drawing: Sky.Drawing
  let light: SkyLight
  var moon: Moon?
  /// Where the moon sits, from the scene's top right corner to its centre.
  var moonInset = CGSize(width: 35, height: 40)
  var moonRadius: CGFloat = 12
  /// The stars' field inside the scene.
  var field = EdgeInsets(top: 24, leading: 24, bottom: 24, trailing: 24)
  /// The land's height at the bottom; none on a tile.
  var horizon: CGFloat = 0
  var land = TollColor.bg
  var names = true
  var atmosphere = true
  /// The newest star's arrival (`SkyNewest`).
  var newestStar: CGFloat = 1
  var newestLines: CGFloat = 1
  var newestLinesShown: CGFloat = 1
  /// A tap near a lit star: its index and where it is, to anchor a popover.
  var tapped: ((Int, CGRect) -> Void)?

  var body: some View {
    GeometryReader { proxy in
      let size = proxy.size
      let layout = Self.layout(drawing, size: size, field: field)
      ZStack(alignment: .topLeading) {
        SkyBackdrop(light: light, atmosphere: atmosphere)
        if let moon {
          SkyMoon(moon: moon, radius: moonRadius)
            .position(x: size.width - moonInset.width, y: moonInset.height)
        }
        SkyStarsLayer(drawing: drawing, layout: layout, names: names)
        SkyNewest(
          drawing: drawing, layout: layout, star: newestStar, lines: newestLines,
          linesShown: newestLinesShown)
        if horizon > 0 {
          SkyHorizon(land: land)
            .frame(width: size.width, height: horizon)
            .offset(y: size.height - horizon)
        }
      }
      .contentShape(Rectangle())
      .allowsHitTesting(tapped != nil)
      .onTapGesture(coordinateSpace: .local) { location in
        guard let tapped,
          let index = layout.nearest(drawing.stars, x: location.x, y: location.y)
        else { return }
        let star = drawing.stars[index]
        tapped(
          index, CGRect(x: layout.x(star.x) - 6, y: layout.y(star.y) - 6, width: 12, height: 12))
      }
    }
    .clipped()
  }

  static func layout(_ drawing: Sky.Drawing, size: CGSize, field: EdgeInsets) -> SkyLayout {
    SkyLayout(
      bounds: drawing.bounds, fieldX: field.leading, fieldY: field.top,
      fieldWidth: max(1, size.width - field.leading - field.trailing),
      fieldHeight: max(1, size.height - field.top - field.bottom))
  }
}
