import ManagedSettings
import ManagedSettingsUI
import TollCore
import TollScreenTime
import UIKit

/// Shield text (G-1, spec §10). Reads App Group state and never writes: writes from here are ignored on
/// device and are a review risk (spec §6). Must return in milliseconds.
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
  private let registry = TokenRegistry()
  private let gateStore = SharedGateStore()

  override func configuration(shielding application: Application) -> ShieldConfiguration {
    let ref = application.token.flatMap { registry.ref(for: $0) }
    return make(name: application.localizedDisplayName, ref: ref)
  }

  override func configuration(shielding application: Application, in category: ActivityCategory)
    -> ShieldConfiguration
  {
    let ref =
      application.token.flatMap { registry.ref(for: $0) }
      ?? category.token.flatMap { registry.ref(for: $0) }
    return make(name: application.localizedDisplayName, ref: ref)
  }

  override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
    make(name: webDomain.domain, ref: webDomain.token.flatMap { registry.ref(for: $0) })
  }

  override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory)
    -> ShieldConfiguration
  {
    make(name: webDomain.domain, ref: webDomain.token.flatMap { registry.ref(for: $0) })
  }

  private func make(name: String?, ref: AppRef?) -> ShieldConfiguration {
    let state = gateStore.load()
    let math = DayMath(timeZone: .current, resetHour: state.resetHour)
    let count = ref.map { state.unblocks(of: $0, on: math.day(containing: Date())) } ?? 0
    let subtitle =
      Self.usesNotificationRoute && !state.notificationsAllowed
      ? Copy.Shield.openFromHomeScreen : Copy.Shield.unblocked(count)
    return ShieldConfiguration(
      backgroundBlurStyle: .systemMaterial,
      backgroundColor: .systemBackground,
      icon: ShieldIcon.image,
      title: .init(text: Copy.Shield.title(name ?? Copy.Shield.fallbackApp), color: .label),
      subtitle: .init(text: subtitle, color: .secondaryLabel),
      primaryButtonLabel: .init(text: Copy.Shield.openToll, color: .white),
      primaryButtonBackgroundColor: ShieldIcon.accent,
      secondaryButtonLabel: .init(text: Copy.Shield.dismiss, color: ShieldIcon.accent))
  }

  private static var usesNotificationRoute: Bool {
    if #available(iOS 26.5, *) { return false }
    return true
  }
}
