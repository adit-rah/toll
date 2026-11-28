@preconcurrency import FamilyControls
@preconcurrency import ManagedSettings
import SwiftUI
import TollCore
import TollUI

/// The editor's Apps row: what's blocked, as up to three of the apps' own icons beside the count
/// (#110), so the row shows its apps without words. With none yet, its tile is the dashed slot Save
/// waits for (#78).
struct AppsRow: View {
  let model: BlockEditorModel
  /// What was chosen when the editor opened: those icons are already in place. Icons that arrive
  /// from Apple's picker fade in and rise, staggered, once (design §2.5).
  let atOpen: FamilyActivitySelection

  var body: some View {
    CardRow(Copy.Blocks.apps, detail: model.appsSummary) {
      if model.hasApps { IconTile(.apps, accent: false) } else { EmptyTile(.apps) }
    } trailing: {
      HStack(spacing: 10) {
        icons
        Chevron()
      }
    }
  }

  @ViewBuilder private var icons: some View {
    HStack(spacing: 4) {
      #if DEBUG
        if let demo = model.demoApps {
          ForEach(0..<min(3, demo.apps + demo.categories), id: \.self) { _ in StandInIcon() }
        }
      #endif
      ForEach(Array(AppIcon.first(3, of: model.selection).enumerated()), id: \.element) {
        index, icon in
        icon.label
          .staggeredAppearance(
            index: index, step: Motion.PickerRows.stagger, rise: Motion.PickerRows.rise,
            isActive: !icon.isIn(atOpen))
      }
    }
    .accessibilityHidden(true)
  }
}

/// One chosen app, category or site, drawn by iOS (`Label(token)`): the app never sees which.
private enum AppIcon: Hashable {
  case app(ApplicationToken)
  case category(ActivityCategoryToken)
  case site(WebDomainToken)

  /// Apps first, then categories, then sites: an app's icon says the most.
  static func first(_ count: Int, of selection: FamilyActivitySelection) -> [AppIcon] {
    let all =
      selection.applicationTokens.map(AppIcon.app)
      + selection.categoryTokens.map(AppIcon.category)
      + selection.webDomainTokens.map(AppIcon.site)
    return Array(all.prefix(count))
  }

  func isIn(_ selection: FamilyActivitySelection) -> Bool {
    switch self {
    case .app(let token): selection.applicationTokens.contains(token)
    case .category(let token): selection.categoryTokens.contains(token)
    case .site(let token): selection.webDomainTokens.contains(token)
    }
  }

  @ViewBuilder var label: some View {
    switch self {
    case .app(let token): Label(token).labelStyle(AppIconLabelStyle())
    case .category(let token): Label(token).labelStyle(AppIconLabelStyle())
    case .site(let token): Label(token).labelStyle(AppIconLabelStyle())
    }
  }
}

#if DEBUG
  /// Where a demo render would draw an app's icon: a plain tile of the icon's size.
  private struct StandInIcon: View {
    var body: some View {
      RoundedRectangle(cornerRadius: AppIconLabelStyle.radius, style: .continuous)
        .fill(TollColor.bar)
        .frame(width: AppIconLabelStyle.side, height: AppIconLabelStyle.side)
    }
  }
#endif
