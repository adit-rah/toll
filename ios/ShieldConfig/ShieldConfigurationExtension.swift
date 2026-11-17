@preconcurrency import ManagedSettings
@preconcurrency import ManagedSettingsUI
import UIKit

/// The block screen (MVP spec §7). Reads App Group state and never writes: writes from here are
/// ignored on device and are a review risk. Must return in milliseconds. Its copy arrives in §12 step 5.
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
    ShieldConfiguration(
      backgroundBlurStyle: .systemMaterial,
      backgroundColor: .systemBackground,
      icon: ShieldIcon.image,
      primaryButtonBackgroundColor: ShieldIcon.accent)
  }
}
