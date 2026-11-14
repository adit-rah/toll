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
  let tokens: TokenRegistry.Tokens?

  public init(_ ref: AppRef, style: Style = .title) {
    self.ref = ref
    self.style = style
    tokens = AppTokenCache.tokens(for: ref)
  }

  public var body: some View {
    Group {
      if let token = tokens?.applications.first {
        styled(Label(token))
      } else if let token = tokens?.webDomains.first {
        styled(Label(token))
      } else if let token = tokens?.categories.first {
        styled(Label(token))
      } else {
        fallback
      }
    }
  }

  @ViewBuilder
  private var fallback: some View {
    #if DEBUG
      if DemoStandIns.active, let name = DemoStandIns.name(for: ref) {
        styled(Label(name, systemImage: "app.fill"))
      } else {
        Text(Copy.Shield.fallbackApp)
      }
    #else
      Text(Copy.Shield.fallbackApp)
    #endif
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

/// A label is rebuilt whenever its screen re-renders, and resolving its token means a coordinated read
/// of the registry file plus a JSON decode. A ref keeps its token for life, so each is resolved once.
/// Refs the registry does not know are retried only after the file changes.
@MainActor
enum AppTokenCache {
  private static var resolved: [AppRef: TokenRegistry.Tokens] = [:]
  private static var unknown: Set<AppRef> = []
  private static var unknownAsOf: Date?

  static func tokens(for ref: AppRef) -> TokenRegistry.Tokens? {
    if let hit = resolved[ref] { return hit }
    let registry = TokenRegistry()
    let modified = (try? registry.url.resourceValues(forKeys: [.contentModificationDateKey]))?
      .contentModificationDate
    if modified != unknownAsOf {
      unknown.removeAll()
      unknownAsOf = modified
    }
    if unknown.contains(ref) { return nil }
    let tokens = registry.tokens(for: [ref])
    if tokens.isEmpty {
      unknown.insert(ref)
      return nil
    }
    resolved[ref] = tokens
    return tokens
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
