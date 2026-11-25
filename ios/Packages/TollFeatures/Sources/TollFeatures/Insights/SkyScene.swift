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
  /// What a tap has opened and brought forward (`SkyFocus`): a tap near a lit star opens its night,
  /// a tap on the open sky brightens or fades the names. Nil where the sky isn't tappable.
  var focus: Binding<SkyFocus>?
  /// What a star's popover shows.
  var night: ((Int) -> AnyView)?

  var body: some View {
    GeometryReader { proxy in
      let size = proxy.size
      let layout = Self.layout(drawing, size: size, field: field)
      let bright = focus?.wrappedValue.figures(in: drawing) ?? []
      ZStack(alignment: .topLeading) {
        SkyBackdrop(light: light, atmosphere: atmosphere)
        if let moon {
          SkyMoon(moon: moon, radius: moonRadius)
            .position(x: size.width - moonInset.width, y: moonInset.height)
        }
        SkyStarsLayer(
          drawing: drawing, layout: layout, names: names, bright: bright, ground: horizon)
        SkyNewest(
          drawing: drawing, layout: layout, star: newestStar, lines: newestLines,
          linesShown: newestLinesShown, bright: bright)
        if horizon > 0 {
          SkyHorizon(land: land)
            .frame(width: size.width, height: horizon)
            .offset(y: size.height - horizon)
        }
        if let focus, let night {
          marker(focus, night: night, layout: layout)
        }
      }
      .contentShape(Rectangle())
      .allowsHitTesting(focus != nil)
      .onTapGesture(coordinateSpace: .local) { location in
        let star = layout.nearest(drawing.stars, x: location.x, y: location.y)
        focus?.wrappedValue.tap(star: star, in: drawing)
      }
    }
    .clipped()
  }

  /// A point on the chosen star, placed by the same layout that drew it, so the popover's arrow
  /// lands on the star. Offset, as Tonight's strip places its targets.
  private func marker(
    _ focus: Binding<SkyFocus>, night: @escaping (Int) -> AnyView, layout: SkyLayout
  ) -> some View {
    let chosen = focus.wrappedValue.star.flatMap {
      drawing.stars.indices.contains($0) ? drawing.stars[$0] : nil
    }
    return Color.clear
      .frame(width: 12, height: 12)
      .popover(
        isPresented: Binding(
          get: { focus.wrappedValue.star != nil },
          set: { if !$0 { focus.wrappedValue.star = nil } })
      ) {
        if let index = focus.wrappedValue.star { night(index) }
      }
      .offset(
        x: (chosen.map { layout.x($0.x) } ?? 0) - 6, y: (chosen.map { layout.y($0.y) } ?? 0) - 6
      )
      .allowsHitTesting(false)
      .accessibilityHidden(true)
  }

  static func layout(_ drawing: Sky.Drawing, size: CGSize, field: EdgeInsets) -> SkyLayout {
    SkyLayout(
      bounds: drawing.bounds, fieldX: field.leading, fieldY: field.top,
      fieldWidth: max(1, size.width - field.leading - field.trailing),
      fieldHeight: max(1, size.height - field.top - field.bottom))
  }
}
