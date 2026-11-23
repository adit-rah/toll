import SwiftUI
import TollCore
import TollUI

/// The night as a picture (D68, #76): moon, start – end, sun, over the strip Tonight draws. Turning the
/// wake wheel slides the night along the strip, so the change shows without words. It changes with no
/// motion: design §2.5 has no row for it.
struct NightPictureView: View {
  let picture: NightPicture

  var body: some View {
    VStack(spacing: 4) {
      HStack(spacing: 10) {
        glyph(.sleep)
        Text(Copy.Setup.nightSpan(start: picture.start, end: picture.end))
          .tollType(.stat, TollColor.label)
          .monospacedDigit()
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
        glyph(.sun)
      }
      .frame(maxWidth: .infinity)
      TimelineStrip(timeline: picture.timeline)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(picture.timeline.label)
  }

  private func glyph(_ symbol: TollSymbol) -> some View {
    Image(symbol: symbol).unredacted()
      .font(.system(size: 18, weight: .medium))
      .foregroundStyle(TollColor.accent)
  }
}
