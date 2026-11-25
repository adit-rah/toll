import SwiftUI
import TollCore
import TollUI

/// The picture a landmark shares (D79), a 1080 × 1920 poster made on the phone: the sky full bleed
/// in the evening's dusk light with its moon and named figures, the land, "30 nights locked", the
/// night's date small and a small wordmark. Nothing else. Always over dark land, so every copy of
/// it is the same picture.
struct SkyPoster: View {
  let landmark: Sky.Landmark

  static let size = CGSize(width: 360, height: 640)

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      SkyScene(
        drawing: landmark.sky, light: .evening, moon: landmark.moon,
        moonInset: CGSize(width: 48, height: 64), moonRadius: 12,
        field: EdgeInsets(top: 104, leading: 26, bottom: 96, trailing: 26), horizon: 72
      )
      .frame(height: 470)
      VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 10) {
          Image(symbol: .sleep).font(.system(size: 20, weight: .medium))
            .foregroundStyle(TollColor.accent)
          Text(landmark.number).tollType(.sheetTitle, TollColor.label)
        }
        if let date = landmark.date {
          Text(date).tollType(.detail, TollColor.label3)
        }
        Spacer(minLength: 0)
        Text(Copy.Sky.wordmark)
          .font(.system(size: 13, weight: .semibold))
          .tracking(2.6)
          .textCase(.uppercase)
          .foregroundStyle(TollColor.label2)
      }
      .padding(.horizontal, 28)
      .padding(.top, 4)
      .padding(.bottom, 30)
    }
    .frame(width: Self.size.width, height: Self.size.height)
    .background(TollColor.bg)
    .environment(\.colorScheme, .dark)
    .environment(\.dynamicTypeSize, .large)
  }
}

/// Shares the landmark's poster through the system share sheet, once it's made. The picture is
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
    let renderer = ImageRenderer(content: SkyPoster(landmark: landmark))
    renderer.scale = 3
    return renderer.uiImage.map { Image(uiImage: $0) }
  }
}
