@preconcurrency import ManagedSettings
@preconcurrency import ManagedSettingsUI
import TollCore
import UIKit

/// The block screen (spec §7). Reads App Group state and never writes: writes from here are ignored
/// on device and are a review risk. Must return in milliseconds.
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
  override func configuration(shielding application: Application) -> ShieldConfiguration {
    make()
  }

  override func configuration(shielding application: Application, in category: ActivityCategory)
    -> ShieldConfiguration
  {
    make()
  }

  override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
    make()
  }

  override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory)
    -> ShieldConfiguration
  {
    make()
  }

  private func make() -> ShieldConfiguration {
    let state = SleepStore().load()
    let title =
      state.blockEndsAt.map { Copy.Shield.title(until: Copy.time($0)) } ?? Copy.Shield.title
    let subtitle =
      state.homeCheck == .windowOnly ? Copy.Shield.subtitleWindowOnly : Copy.Shield.subtitle
    return ShieldConfiguration(
      backgroundBlurStyle: .systemMaterial,
      backgroundColor: .systemBackground,
      icon: ShieldIcon.image,
      title: .init(text: title, color: .label),
      subtitle: .init(text: subtitle, color: .secondaryLabel),
      primaryButtonLabel: .init(text: Copy.Shield.open, color: ShieldIcon.onAccent),
      primaryButtonBackgroundColor: ShieldIcon.accent,
      secondaryButtonLabel: .init(text: Copy.Shield.ok, color: ShieldIcon.accent))
  }
}
