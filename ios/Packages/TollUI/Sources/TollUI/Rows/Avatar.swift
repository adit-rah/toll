import SwiftUI
import UIKit

/// Design §3.17. A photo, or the name's first letter on a muted tone hashed from the handle. Never a
/// coloured ring or an online dot. Decorative for VoiceOver: the row around it says who it is.
public struct Avatar: View {
  public enum Size: CGFloat, Sendable {
    case row = 32
    case settings = 40
    case detail = 44
    case profile = 96
  }

  let name: String
  let handle: String
  let photoURL: URL?
  let size: CGFloat
  let status: StatusMark?
  let backing: Color
  @State private var loaded: LoadedPhoto? = nil
  @Environment(\.displayScale) private var displayScale

  /// `backing` is the colour the avatar sits on, so the badge's disc disappears into it: `bg` on Home,
  /// `surface` inside a grouped list.
  public init(
    name: String, handle: String, photoURL: URL? = nil, size: Size = .row,
    status: StatusMark? = nil, backing: Color = TollColor.bg
  ) {
    self.name = name
    self.handle = handle
    self.photoURL = photoURL
    self.size = size.rawValue
    self.status = status
    self.backing = backing
  }

  public var body: some View {
    ZStack {
      if let photo {
        Image(uiImage: photo).resizable().scaledToFill()
      } else {
        initial
      }
    }
    .frame(width: size, height: size)
    .clipShape(Circle())
    .overlay(alignment: .bottomTrailing) {
      if let status {
        // The disc keeps the badge legible on any photo (design §3.4).
        StatusGlyph(status, size: .badge)
          .frame(width: 16, height: 16)
          .background(backing, in: Circle())
          .offset(x: 3, y: 3)
      }
    }
    .accessibilityHidden(true)
    .task(id: photoURL) { await load() }
  }

  private var initial: some View {
    ZStack {
      TollColor.avatarTone(for: handle.isEmpty ? name : handle)
      Text(verbatim: name.first.map { String($0).uppercased() } ?? "")
        .font(.system(size: size * 0.42, weight: .semibold))
        .foregroundStyle(TollColor.avatarInitial)
    }
  }

  private var pixels: Int { Int((size * displayScale).rounded(.up)) }

  // The cache is read here, not only in the task, so a row scrolling back in draws its photo on the
  // first frame instead of flashing the initial.
  private var photo: UIImage? {
    guard let photoURL else { return nil }
    if let loaded, loaded.url == photoURL { return loaded.image }
    return AvatarPhotos.shared.cached(photoURL, pixels: pixels)
  }

  private func load() async {
    guard let photoURL, photo == nil else { return }
    let image = await AvatarPhotos.shared.photo(photoURL, pixels: pixels)
    guard let image, !Task.isCancelled else { return }
    loaded = LoadedPhoto(url: photoURL, image: image)
  }
}

private struct LoadedPhoto {
  let url: URL
  let image: UIImage
}

/// Photos decoded at the size they are drawn. A photo URL never changes its bytes (a new photo gets a
/// new URL), so an entry cannot go stale.
@MainActor
final class AvatarPhotos {
  static let shared = AvatarPhotos()
  private let images = NSCache<NSString, UIImage>()

  private init() {
    images.countLimit = 200
  }

  func cached(_ url: URL, pixels: Int) -> UIImage? {
    images.object(forKey: key(url, pixels))
  }

  func photo(_ url: URL, pixels: Int) async -> UIImage? {
    if let hit = cached(url, pixels: pixels) { return hit }
    guard let image = await Self.fetch(url, pixels: pixels) else { return nil }
    images.setObject(image, forKey: key(url, pixels))
    return image
  }

  private func key(_ url: URL, _ pixels: Int) -> NSString {
    "\(url.absoluteString)#\(pixels)" as NSString
  }

  // Off the main actor, and straight to a thumbnail: a 512 px photo decoded whole is a megabyte per
  // friend, to be drawn at 32 pt.
  private nonisolated static func fetch(_ url: URL, pixels: Int) async -> UIImage? {
    guard let (data, _) = try? await URLSession.shared.data(from: url),
      let full = UIImage(data: data)
    else { return nil }
    let shortest = min(full.size.width, full.size.height) * full.scale
    guard shortest > 0 else { return nil }
    let factor = min(1, CGFloat(pixels) / shortest)
    let target = CGSize(width: full.size.width * factor, height: full.size.height * factor)
    return full.preparingThumbnail(of: target) ?? full
  }
}
