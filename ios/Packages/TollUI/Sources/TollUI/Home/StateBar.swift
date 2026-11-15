import SwiftUI

/// Home's state bar (design §3.18): one fact in two lines, docked above the tab bar. It has no
/// buttons of its own: the whole bar opens the sheet that says more, and VoiceOver reads it as one
/// sentence with a hint.
public struct StateBar<Icon: View, Title: View, Line: View>: View {
  /// Nil when the bar names apps: the system's labels are read in place, since Toll cannot read them.
  let spoken: String?
  let hint: String
  let action: () -> Void
  let icon: Icon
  let title: Title
  let line: Line
  @Environment(\.dynamicTypeSize) private var typeSize

  public init(
    spoken: String?, hint: String, action: @escaping () -> Void, @ViewBuilder icon: () -> Icon,
    @ViewBuilder title: () -> Title, @ViewBuilder line: () -> Line
  ) {
    self.spoken = spoken
    self.hint = hint
    self.action = action
    self.icon = icon()
    self.title = title()
    self.line = line()
  }

  private static let minHeight: CGFloat = 64

  public var body: some View {
    Button(action: action) {
      HStack(spacing: TollSpacing.rowLeadingGap) {
        icon
        VStack(alignment: .leading, spacing: 1) {
          title
            .font(TollFont.subheadSemibold)
            .foregroundStyle(TollColor.label)
          line
            .font(TollFont.detail)
            .foregroundStyle(TollColor.label2)
            .monospacedDigit()
        }
        // At accessibility sizes the lines wrap instead of cutting the names off.
        .lineLimit(typeSize.isAccessibilitySize ? 3 : 1)
        .frame(maxWidth: .infinity, alignment: .leading)
        Image(systemName: "chevron.right")
          .font(TollFont.captionMedium)
          .foregroundStyle(TollColor.label3)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
      .frame(minHeight: Self.minHeight)
      .contentShape(RoundedRectangle(cornerRadius: TollRadius.card, style: .continuous))
      .modifier(StateBarSurface())
    }
    .buttonStyle(.plain)
    .modifier(SpokenAs(spoken: spoken))
    .accessibilityHint(hint)
    .accessibilityAddTraits(.isButton)
  }
}

private struct SpokenAs: ViewModifier {
  let spoken: String?

  func body(content: Content) -> some View {
    if let spoken {
      content.accessibilityElement(children: .ignore).accessibilityLabel(spoken)
    } else {
      content.accessibilityElement(children: .combine)
    }
  }
}

/// `floating` with a hairline, and in light mode a soft shadow so it reads as above the list that
/// scrolls under it. Dark mode has no shadows (design §2.4).
private struct StateBarSurface: ViewModifier {
  @Environment(\.displayScale) private var displayScale
  @Environment(\.colorScheme) private var colorScheme

  func body(content: Content) -> some View {
    let outline = RoundedRectangle(cornerRadius: TollRadius.card, style: .continuous)
    content
      .background(TollColor.floating, in: outline)
      .overlay {
        outline.strokeBorder(TollColor.separator.opacity(0.6), lineWidth: 1 / displayScale)
      }
      .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.06), radius: 10, y: 6)
  }
}

/// The 36 pt tile that leads the bar and the sheet when the subject is not an app: a shield, a clock.
public struct SymbolTile: View {
  let systemName: String
  let tint: Color

  public init(_ systemName: String, tint: Color = TollColor.label2) {
    self.systemName = systemName
    self.tint = tint
  }

  public var body: some View {
    Image(systemName: systemName)
      .font(.system(size: 17, weight: .medium))
      .foregroundStyle(tint)
      .frame(width: 36, height: 36)
      .background(TollColor.fill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
      .accessibilityHidden(true)
  }
}
