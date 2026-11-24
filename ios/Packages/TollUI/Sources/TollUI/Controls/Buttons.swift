import SwiftUI

/// The canvas's 54 pt button, 16 pt corners, 17 pt semibold. One main button per screen.
public struct PrimaryButtonStyle: ButtonStyle {
  public enum Tone: Sendable {
    /// Amber: the screen's main action.
    case accent
    /// `surfaceRaised` with `label` text: a second, equal choice ("Choose again").
    case neutral
    /// The warn colour on its 12% tint: "Delete block" in its sheet.
    case warn
  }

  let tone: Tone

  public init(tone: Tone = .accent) {
    self.tone = tone
  }

  public func makeBody(configuration: Configuration) -> some View {
    PrimaryButtonBody(label: configuration.label, isPressed: configuration.isPressed, tone: tone)
  }
}

private struct PrimaryButtonBody<Label: View>: View {
  let label: Label
  let isPressed: Bool
  let tone: PrimaryButtonStyle.Tone
  @Environment(\.isEnabled) private var isEnabled

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: TollRadius.button, style: .continuous)
    label
      .tollType(.button, isEnabled ? foreground : TollColor.label3)
      .lineLimit(2)
      .multilineTextAlignment(.center)
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
      .frame(maxWidth: .infinity, minHeight: 54)
      .background(isEnabled ? background : TollColor.surfaceRaised, in: shape)
      .opacity(isPressed ? 0.85 : 1)
      .contentShape(shape)
  }

  private var foreground: Color {
    switch tone {
    case .accent: TollColor.onAccent
    case .neutral: TollColor.label
    case .warn: TollColor.warn
    }
  }

  private var background: Color {
    switch tone {
    case .accent: TollColor.accent
    case .neutral: TollColor.surfaceRaised
    case .warn: TollColor.warnSoft
    }
  }
}

/// Text only, with a 44 pt hit area: "Cancel", "Not now", "Restore purchase", "Delete block".
public struct QuietButtonStyle: ButtonStyle {
  public enum Tone: Sendable {
    case accent
    case secondary
    case warn
  }

  let tone: Tone
  let type: TollType

  public init(tone: Tone = .secondary, type: TollType = .quiet) {
    self.tone = tone
    self.type = type
  }

  public func makeBody(configuration: Configuration) -> some View {
    QuietButtonBody(
      label: configuration.label, isPressed: configuration.isPressed, tone: tone, type: type)
  }
}

private struct QuietButtonBody<Label: View>: View {
  let label: Label
  let isPressed: Bool
  let tone: QuietButtonStyle.Tone
  let type: TollType
  @Environment(\.isEnabled) private var isEnabled

  var body: some View {
    label
      .tollType(type, isEnabled ? color : TollColor.label3)
      .multilineTextAlignment(.center)
      .frame(minWidth: TollSpacing.minTapTarget, minHeight: TollSpacing.minTapTarget)
      .contentShape(Rectangle())
      .opacity(isPressed ? 0.5 : 1)
  }

  private var color: Color {
    switch tone {
    case .accent: TollColor.accent
    case .secondary: TollColor.label2
    case .warn: TollColor.warn
    }
  }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
  public static var tollPrimary: PrimaryButtonStyle { PrimaryButtonStyle() }
  public static var tollSecondary: PrimaryButtonStyle { PrimaryButtonStyle(tone: .neutral) }
  public static var tollWarn: PrimaryButtonStyle { PrimaryButtonStyle(tone: .warn) }
}

extension ButtonStyle where Self == QuietButtonStyle {
  public static var tollQuiet: QuietButtonStyle { QuietButtonStyle() }
  public static var tollAccentQuiet: QuietButtonStyle {
    QuietButtonStyle(tone: .accent, type: .link)
  }
  public static var tollDestructiveQuiet: QuietButtonStyle {
    QuietButtonStyle(tone: .warn, type: .link)
  }
}

/// The label is a view so a door button can carry `Label(token)` without knowing the app's name.
public struct PrimaryButton<Label: View>: View {
  let action: () -> Void
  let tone: PrimaryButtonStyle.Tone
  let label: Label

  public init(
    tone: PrimaryButtonStyle.Tone = .accent, action: @escaping () -> Void,
    @ViewBuilder label: () -> Label
  ) {
    self.action = action
    self.tone = tone
    self.label = label()
  }

  public var body: some View {
    Button(action: action) { label }
      .buttonStyle(PrimaryButtonStyle(tone: tone))
  }
}

extension PrimaryButton where Label == Text {
  public init(
    _ title: String, tone: PrimaryButtonStyle.Tone = .accent, action: @escaping () -> Void
  ) {
    self.init(tone: tone, action: action) { Text(title) }
  }
}

/// A quiet action. Secondary grey at 15 pt medium unless told otherwise.
public struct QuietButton: View {
  let title: String
  let tone: QuietButtonStyle.Tone
  let type: TollType
  let action: () -> Void

  public init(
    _ title: String, tone: QuietButtonStyle.Tone = .secondary, type: TollType = .quiet,
    action: @escaping () -> Void
  ) {
    self.title = title
    self.tone = tone
    self.type = type
    self.action = action
  }

  public var body: some View {
    Button(title, action: action)
      .buttonStyle(QuietButtonStyle(tone: tone, type: type))
  }
}

/// "Delete block": the warn colour, 15 pt semibold, with the trash symbol.
public struct DestructiveQuiet: View {
  let title: String
  let action: () -> Void

  public init(_ title: String, action: @escaping () -> Void) {
    self.title = title
    self.action = action
  }

  public var body: some View {
    Button(role: .destructive, action: action) {
      HStack(spacing: 8) {
        Image(symbol: .delete).unredacted().font(.system(size: 15, weight: .semibold))
        Text(title)
      }
    }
    .buttonStyle(QuietButtonStyle(tone: .warn, type: .link))
  }
}

/// A link that leaves for iOS Settings ("Turn on", "Change in Settings"): accent text with the
/// open-Settings glyph, so it reads as "go elsewhere" without the words (#72, rule 3).
public struct SettingsLink: View {
  let title: String
  let action: () -> Void

  public init(_ title: String, action: @escaping () -> Void) {
    self.title = title
    self.action = action
  }

  public var body: some View {
    Button(action: action) {
      HStack(spacing: 6) {
        Text(title)
        Image(symbol: .openSettings).unredacted()
          .font(.system(size: 13, weight: .semibold))
          .accessibilityHidden(true)
      }
    }
    .tollType(.link, TollColor.accent)
    .frame(minHeight: 28)
  }
}

/// A tappable shape drawn by its own view (the free-week pill, the strip's segments): it dims while
/// pressed, like a quiet button, so a tap visibly lands (D75). No motion: the change is immediate.
public struct PressableStyle: ButtonStyle {
  public init() {}

  public func makeBody(configuration: Configuration) -> some View {
    configuration.label.opacity(configuration.isPressed ? 0.55 : 1)
  }
}

extension ButtonStyle where Self == PressableStyle {
  public static var tollPressable: PressableStyle { PressableStyle() }
}
