import SwiftUI
import TollCore
import TollUI

/// A landmark morning on the morning card (D79): the shape last night's star completed, one quiet
/// line, and the share glyph. It arrives with the card and leaves with it; no motion of its own.
struct LandmarkLine: View {
  let landmark: Sky.Landmark
  @Environment(\.dynamicTypeSize) private var typeSize
  @ScaledMetric(relativeTo: .body) private var tile: CGFloat = 56

  var body: some View {
    let layout =
      typeSize.isAccessibilitySize
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
      : AnyLayout(HStackLayout(spacing: TollSpacing.rowGap))
    layout {
      // The same renderer as Your sleep and the shared picture, in the picture's dusk light.
      SkyScene(
        drawing: landmark.shape, light: .evening,
        field: EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8), names: false,
        atmosphere: typeSize.isAccessibilitySize
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
