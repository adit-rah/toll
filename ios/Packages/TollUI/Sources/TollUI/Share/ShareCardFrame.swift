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
      // The line keeps its height with the name off, so the toggle never moves the numeral.
      Text(displayName ?? Copy.ShareCards.wordmark)
        .tollText(.caption)
        .lineLimit(1)
        .opacity(displayName == nil ? 0 : 1)
        .accessibilityHidden(displayName == nil)
      Spacer(minLength: 16)
      content
        .frame(maxWidth: .infinity, alignment: .leading)
      Spacer(minLength: 16)
      HStack(alignment: .bottom) {
        Wordmark()
          .fixedSize()
        Spacer(minLength: 12)
        VStack(alignment: .trailing, spacing: 2) {
          Text(dateRange).monospacedDigit()
          Text(inviteLink)
        }
        .font(TollFont.caption)
        .foregroundStyle(TollColor.label2)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
      }
    }
    .padding(.horizontal, 24)
    .padding(.top, format.safeTop)
    .padding(.bottom, format.safeBottom)
    .frame(width: format.size.width, height: format.size.height)
    .background(canvas)
    .clipped()
    .environment(\.colorScheme, colorScheme)
    .dynamicTypeSize(.large)
  }

  /// Fixed, not `bg`: inside a sheet the system background resolves to its raised grey, so the
  /// preview and the exported image would differ, and pure black is harsher than the app ever is.
  private var canvas: Color {
    colorScheme == .dark ? Color(red: 15 / 255, green: 17 / 255, blue: 21 / 255) : Color.white
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
