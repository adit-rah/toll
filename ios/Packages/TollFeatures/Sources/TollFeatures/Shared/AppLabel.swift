@preconcurrency import FamilyControls
@preconcurrency import ManagedSettings
import SwiftUI
import TollCore
import TollScreenTime

/// The system's own name and icon for a picked token. Toll can show these but never read them as text
/// (spec §6), which is why friends see tags instead.
public struct AppLabel: View {
  public enum Style { case title, icon, both }

  let ref: AppRef
  let style: Style
  let tokens: TokenRegistry.Tokens

  public init(_ ref: AppRef, style: Style = .title) {
    self.ref = ref
    self.style = style
    tokens = TokenRegistry().tokens(for: [ref])
  }

  public var body: some View {
    Group {
      if let token = tokens.applications.first {
        styled(Label(token))
      } else if let token = tokens.webDomains.first {
        styled(Label(token))
      } else if let token = tokens.categories.first {
        styled(Label(token))
      } else {
        Text(Copy.Shield.fallbackApp)
      }
    }
  }

  @ViewBuilder
  private func styled(_ label: some View) -> some View {
    switch style {
    case .title: label.labelStyle(.titleOnly)
    case .icon: label.labelStyle(.iconOnly)
    case .both: label
    }
  }
}

/// Up to three overlapping icons (design §3.10).
public struct AppIconCluster: View {
  let refs: [AppRef]
  let size: CGFloat

  public init(_ refs: [AppRef], size: CGFloat = 28) {
    self.refs = refs
    self.size = size
  }

  public var body: some View {
    HStack(spacing: -6) {
      ForEach(Array(refs.prefix(3)), id: \.self) { ref in
        AppLabel(ref, style: .icon)
          .frame(width: size, height: size)
          .accessibilityHidden(true)
      }
    }
  }
}
