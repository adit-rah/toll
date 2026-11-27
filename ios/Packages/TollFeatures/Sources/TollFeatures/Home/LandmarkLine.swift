import SwiftUI
import TollCore
import TollUI

/// A landmark night on last night's card (D79): the shape last night's star completed under last
/// night's moon, as the sky and the shared picture carry it (#137), one quiet line, and the share
/// glyph. It arrives with the card and leaves with it; no motion of its own.
struct LandmarkLine: View {
  let landmark: Sky.Landmark
  @Environment(\.dynamicTypeSize) private var typeSize
  @ScaledMetric(relativeTo: .body) private var tile: CGFloat = 56

  var body: some View {
    let wide = typeSize.isAccessibilitySize
    let layout =
      wide
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
      : AnyLayout(HStackLayout(spacing: TollSpacing.rowGap))
    layout {
      // The same renderer as Your sleep and the shared picture, in the picture's dusk light. The
      // moon keeps to the top right corner, and the shape keeps clear of it.
      SkyScene(
        drawing: landmark.shape, light: .evening, moon: landmark.moon,
        moonInset: wide ? CGSize(width: 22, height: 22) : CGSize(width: 11, height: 11),
        moonRadius: wide ? 7 : 4.5,
        field: wide
          ? EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 44)
          : EdgeInsets(top: 18, leading: 8, bottom: 8, trailing: 8),
        names: false, atmosphere: wide
      )
      .clipShape(RoundedRectangle(cornerRadius: TollRadius.field, style: .continuous))
      .accessibilityHidden(true)
      .frame(
        width: typeSize.isAccessibilitySize ? nil : min(tile, 84),
        height: typeSize.isAccessibilitySize ? 120 : min(tile, 84)
      )
      .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : nil)
      HStack(spacing: 8) {
        Text(landmark.line)
          .tollType(.rowTitle, TollColor.label)
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: .infinity, alignment: .leading)
        SkyShare(landmark: landmark)
      }
    }
  }
}
