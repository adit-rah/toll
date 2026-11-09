import SwiftUI
import TollCore

public enum ShareCardFormat: Sendable {
  case story
  case square

  public var size: CGSize {
    switch self {
    case .story: CGSize(width: 360, height: 640)
    case .square: CGSize(width: 360, height: 360)
    }
  }

  // Story apps draw their own chrome over the top 90 pt and bottom 130 pt.
  var safeTop: CGFloat { self == .story ? 90 : 24 }
  var safeBottom: CGFloat { self == .story ? 130 : 24 }
}

/// Design §3.14. An opaque canvas rendered with `ImageRenderer` at scale 3. The appearance and type size
/// are fixed here so the image is the same whatever the phone is set to; the content slot holds the
/// hero numeral (`HeroNumber(_, size: 96)`), one fact line and one small chart.
public struct ShareCardFrame<Content: View>: View {
  let format: ShareCardFormat
  let colorScheme: ColorScheme
  let displayName: String?
  let dateRange: String
  let inviteLink: String
  let content: Content

  public init(
    format: ShareCardFormat, colorScheme: ColorScheme, displayName: String?, dateRange: String,
    inviteLink: String, @ViewBuilder content: () -> Content
  ) {
    self.format = format
    self.colorScheme = colorScheme
    self.displayName = displayName
    self.dateRange = dateRange
    self.inviteLink = inviteLink
    self.content = content()
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      if let displayName {
        Text(displayName).tollText(.caption).lineLimit(1)
      }
      Spacer(minLength: 16)
      content
        .frame(maxWidth: .infinity)
      Spacer(minLength: 16)
      HStack(alignment: .bottom) {
        Wordmark()
        Spacer(minLength: 12)
        VStack(alignment: .trailing, spacing: 2) {
          Text(dateRange).monospacedDigit()
          Text(inviteLink)
        }
        .font(TollFont.caption)
        .foregroundStyle(TollColor.label2)
        .lineLimit(1)
      }
    }
    .padding(.horizontal, 24)
    .padding(.top, format.safeTop)
    .padding(.bottom, format.safeBottom)
    .frame(width: format.size.width, height: format.size.height)
    .background(TollColor.bg)
    .environment(\.colorScheme, colorScheme)
    .dynamicTypeSize(.large)
  }
}

/// Placeholder wordmark (toll-brand-tbd.md): the name in semibold caps beside a ring, 12 pt.
private struct Wordmark: View {
  var body: some View {
    HStack(spacing: 5) {
      Circle()
        .strokeBorder(TollColor.label, lineWidth: 2)
        .frame(width: 12, height: 12)
      Text(Copy.ShareCards.wordmark)
        .font(.system(size: 12, weight: .semibold))
        .tracking(1)
        .foregroundStyle(TollColor.label)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Copy.Welcome.name)
  }
}
