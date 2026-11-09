import SwiftUI

/// Design §3.12. Full width, 50 pt, accent fill. One per screen.
public struct PrimaryButtonStyle: ButtonStyle {
  public init() {}

  public func makeBody(configuration: Configuration) -> some View {
    PrimaryButtonBody(label: configuration.label, isPressed: configuration.isPressed)
  }
}

private struct PrimaryButtonBody<Label: View>: View {
  let label: Label
  let isPressed: Bool
  @Environment(\.isEnabled) private var isEnabled

  var body: some View {
    label
      .font(TollFont.headline)
      .foregroundStyle(isEnabled ? TollColor.onAccent : TollColor.label3)
      .lineLimit(2)
      .multilineTextAlignment(.center)
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
      .frame(maxWidth: .infinity, minHeight: 50)
      .background(
        isEnabled ? TollColor.accent : TollColor.surfaceRaised,
        in: RoundedRectangle(cornerRadius: TollRadius.button, style: .continuous)
      )
      .opacity(isPressed ? 0.85 : 1)
      .contentShape(RoundedRectangle(cornerRadius: TollRadius.button, style: .continuous))
  }
}

/// Text-only, `body` medium, with a 44 pt hit area. Cancel, Skip, Add.
public struct QuietButtonStyle: ButtonStyle {
  public enum Tone: Sendable {
    case accent
    /// `label2`, for the three quiet actions at the bottom of Friend detail.
    case secondary
    case destructive
  }

  let tone: Tone

  public init(tone: Tone = .accent) {
    self.tone = tone
  }

  public func makeBody(configuration: Configuration) -> some View {
    QuietButtonBody(label: configuration.label, isPressed: configuration.isPressed, tone: tone)
  }
}

private struct QuietButtonBody<Label: View>: View {
  let label: Label
  let isPressed: Bool
  let tone: QuietButtonStyle.Tone
  @Environment(\.isEnabled) private var isEnabled

  var body: some View {
    label
      .font(TollFont.bodyMedium)
      .foregroundStyle(isEnabled ? color : TollColor.label3)
      .frame(minWidth: TollSpacing.minTapTarget, minHeight: TollSpacing.minTapTarget)
      .contentShape(Rectangle())
      .opacity(isPressed ? 0.5 : 1)
  }

  private var color: Color {
    switch tone {
    case .accent: TollColor.accent
    case .secondary: TollColor.label2
    case .destructive: TollColor.destructive
    }
  }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
  public static var tollPrimary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == QuietButtonStyle {
  public static var tollQuiet: QuietButtonStyle { QuietButtonStyle() }
  public static var tollDestructiveQuiet: QuietButtonStyle { QuietButtonStyle(tone: .destructive) }
}

/// The label is a view so the gate can read "Open <Label(token)>" without knowing the app's name.
public struct PrimaryButton<Label: View>: View {
  let action: () -> Void
  let label: Label

  public init(action: @escaping () -> Void, @ViewBuilder label: () -> Label) {
    self.action = action
    self.label = label()
  }

  public var body: some View {
    Button(action: action) { label }
      .buttonStyle(PrimaryButtonStyle())
  }
}

extension PrimaryButton where Label == Text {
  public init(_ title: String, action: @escaping () -> Void) {
    self.init(action: action) { Text(title) }
  }
}

public struct QuietButton: View {
  let title: String
  let tone: QuietButtonStyle.Tone
  let action: () -> Void

  public init(
    _ title: String, tone: QuietButtonStyle.Tone = .accent, action: @escaping () -> Void
  ) {
    self.title = title
    self.tone = tone
    self.action = action
  }

  public var body: some View {
    Button(title, action: action)
      .buttonStyle(QuietButtonStyle(tone: tone))
  }
}

/// Text-only in systemRed: Remove, Delete account.
public struct DestructiveQuiet: View {
  let title: String
  let action: () -> Void

  public init(_ title: String, action: @escaping () -> Void) {
    self.title = title
    self.action = action
  }

  public var body: some View {
    Button(title, role: .destructive, action: action)
      .buttonStyle(QuietButtonStyle(tone: .destructive))
  }
}
