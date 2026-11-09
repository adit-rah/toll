import SwiftUI

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

  public init(
    name: String, handle: String, photoURL: URL? = nil, size: Size = .row,
    status: StatusMark? = nil
  ) {
    self.name = name
    self.handle = handle
    self.photoURL = photoURL
    self.size = size.rawValue
    self.status = status
  }

  public var body: some View {
    AsyncImage(url: photoURL) { phase in
      if let image = phase.image {
        image.resizable().scaledToFill()
      } else {
        initial
      }
    }
    .frame(width: size, height: size)
    .clipShape(Circle())
    .overlay(alignment: .bottomTrailing) {
      if let status {
        // The bg disc keeps the badge legible on any photo (design §3.4).
        StatusGlyph(status, size: .badge)
          .frame(width: 16, height: 16)
          .background(TollColor.bg, in: Circle())
          .offset(x: 3, y: 3)
      }
    }
    .accessibilityHidden(true)
  }

  private var initial: some View {
    ZStack {
      TollColor.avatarTone(for: handle.isEmpty ? name : handle)
      Text(verbatim: name.first.map { String($0).uppercased() } ?? "")
        .font(.system(size: size * 0.42, weight: .semibold))
        .foregroundStyle(TollColor.avatarInitial)
    }
  }
}
