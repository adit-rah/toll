@preconcurrency import ManagedSettings
@preconcurrency import ManagedSettingsUI
import TollCore
import TollScreenTime
import UIKit

/// The block screen (spec §7, D32). Reads the shared state and never writes: writes from here are
/// ignored on device and are a review risk. Must return in milliseconds.
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
  override func configuration(shielding application: Application) -> ShieldConfiguration {
    make(app: application.token, category: nil)
  }

  override func configuration(shielding application: Application, in category: ActivityCategory)
    -> ShieldConfiguration
  {
    make(app: application.token, category: category.token)
  }

  override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
    make(app: nil, category: nil)
  }

  override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory)
    -> ShieldConfiguration
  {
    make(app: nil, category: category.token)
  }

  private func make(app: ApplicationToken?, category: ActivityCategoryToken?) -> ShieldConfiguration
  {
    let state = DuskStore().load()
    let text = ShieldText(
      state: state, block: block(in: state, app: app, category: category), now: Date())
    return ShieldConfiguration(
      backgroundBlurStyle: nil,
      backgroundColor: ShieldIcon.background,
      icon: ShieldIcon.image(kind: text.kind, left: text.unlocksLeft, max: text.unlocksMax),
      title: .init(text: text.title, color: ShieldIcon.label),
      subtitle: .init(text: text.subtitle, color: ShieldIcon.secondaryLabel),
      primaryButtonLabel: .init(text: Copy.Shield.neverMind, color: ShieldIcon.onAccent),
      primaryButtonBackgroundColor: ShieldIcon.accent,
      secondaryButtonLabel: text.offersDoor
        ? .init(text: Copy.Shield.unlock, color: ShieldIcon.secondaryLabel) : nil)
  }

  /// The active block that names this app; the Sleep block when several do or none can be told apart.
  private func block(in state: DuskState, app: ApplicationToken?, category: ActivityCategoryToken?)
    -> Block?
  {
    let active = state.activeBlocks
    let naming = Blocklist.blocks(active, containing: app, category: category)
    return naming.first(where: \.isSleep) ?? naming.first ?? active.first(where: \.isSleep)
      ?? active.first
  }
}
