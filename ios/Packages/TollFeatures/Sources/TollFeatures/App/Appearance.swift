import SwiftUI
import TollCore

/// Dark first, switchable (decisions D36). A per-phone display choice, so it lives with the views in
/// the app's own defaults, not in the shared state the extensions read.
enum Appearance: String, CaseIterable, Identifiable {
  case dark, light, system

  static let key = "appearance"
  static let standard = Appearance.dark

  var id: String { rawValue }

  var scheme: ColorScheme? {
    switch self {
    case .dark: .dark
    case .light: .light
    case .system: nil
    }
  }

  var title: String {
    switch self {
    case .dark: Copy.Settings.dark
    case .light: Copy.Settings.light
    case .system: Copy.Settings.matchPhone
    }
  }
}
