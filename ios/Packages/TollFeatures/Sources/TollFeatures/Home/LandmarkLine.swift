import SwiftUI
import TollCore
import TollUI

/// A landmark morning (D79): under the morning's hero, one quiet line, as another block's is: the
/// shape last night's star completed as a small tile, the line, and the share glyph. It arrives and
/// leaves with the morning; no motion of its own.
struct LandmarkLine: View {
  let landmark: Sky.Landmark
  @Environment(\.dynamicTypeSize) private var typeSize
  @ScaledMetric(relativeTo: .body) private var tile: CGFloat = 44

  var body: some View {
    let layout =
      typeSize.isAccessibilitySize
      ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 12))
    let side = min(tile, 64)
    layout {
      // The same renderer as Your sleep and the shared picture, in the picture's dusk light.
      SkyScene(
        drawing: landmark.shape, light: .evening,
        field: EdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6), names: false,
        atmosphere: false
      )
      .clipShape(RoundedRectangle(cornerRadius: TollRadius.field, style: .continuous))
      .accessibilityHidden(true)
      .frame(width: side, height: side)
      Text(landmark.line)
        .tollType(.heroLine, TollColor.label2)
        .fixedSize(horizontal: false, vertical: true)
        .multilineTextAlignment(typeSize.isAccessibilitySize ? .center : .leading)
      SkyShare(landmark: landmark)
    }
    .frame(maxWidth: .infinity)
  }
}
