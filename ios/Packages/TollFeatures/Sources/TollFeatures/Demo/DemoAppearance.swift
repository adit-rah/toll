#if DEBUG
  import Foundation
  import TollCore

  /// Demos follow the simulator's appearance, so renders show both (docs/renders.md), except the
  /// scenarios that show "Dark in the evening".
  extension DemoScenario {
    var scheme: Appearance.Scheme? {
      guard self == .homeEveningDark else { return nil }
      return Appearance.light.scheme(
        at: DemoClock.now(for: self), darkInEvening: true, calendar: .current)
    }

    /// Settings' picker reads the stored choice; a registered default is kept out of the store.
    func registerAppearance() {
      guard self == .settingsLight || self == .homeEveningDark else { return }
      UserDefaults.standard.register(defaults: [Appearance.key: Appearance.light.rawValue])
    }
  }
#endif
