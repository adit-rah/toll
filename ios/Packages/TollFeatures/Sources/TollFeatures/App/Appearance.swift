import SwiftUI
import TollCore

/// A per-phone display choice (D36), so it lives with the views in the app's own defaults, not in
/// the shared state the extensions read. The rule is `TollCore.Appearance`.
extension Appearance {
  static let key = "appearance"
  static let standard = Appearance.dark
  /// "Dark in the evening": on unless switched off.
  static let eveningKey = "darkInEvening"
  static let eveningStandard = true

  var title: String {
    switch self {
    case .dark: Copy.Settings.dark
    case .light: Copy.Settings.light
    case .system: Copy.Settings.matchPhone
    }
  }
}

extension Appearance.Scheme {
  var colorScheme: ColorScheme {
    switch self {
    case .dark: .dark
    case .light: .light
    }
  }
}
