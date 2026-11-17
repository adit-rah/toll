import SwiftUI
import UIKit

/// Design §2.3. Every colour on screen comes from here so the placeholder accent swaps in one place.
public enum TollColor {
  public static let bg = Color(uiColor: .systemBackground)
  public static let bgGrouped = Color(uiColor: .systemGroupedBackground)
  public static let surface = Color(uiColor: .secondarySystemGroupedBackground)
  public static let surfaceRaised = Color(uiColor: .tertiarySystemGroupedBackground)
  /// Home's state bar (design §3.18): `#F2F2F7` on the white page, `#1C1C1E` on the black one, so it
  /// stands off the page in both without glass.
  public static let floating = Color(uiColor: .secondarySystemBackground)
  /// Translucent, so it reads on `bg`, `bgGrouped` and `surface` alike. For controls that can sit on
  /// any of them: a disabled button, a field inside a list row.
  public static let fill = Color(uiColor: .tertiarySystemFill)

  public static let label = Color(uiColor: .label)
  public static let label2 = Color(uiColor: .secondaryLabel)
  public static let label3 = Color(uiColor: .tertiaryLabel)
  public static let separator = Color(uiColor: .separator)
  public static let destructive = Color(uiColor: .systemRed)

  // Placeholder accent (toll-brand-tbd.md). Increased-contrast values darken in light and lighten in
  // dark so 17 pt text stays above 4.5:1 with margin.
  public static let accent = dynamic(
    light: 0x3A6EA5, dark: 0x8FB4E3, lightContrast: 0x2B5683, darkContrast: 0xB0CBEE)
  public static let accentSoft = dynamic(
    light: 0x3A6EA5, dark: 0x8FB4E3, lightAlpha: 0.12, darkAlpha: 0.18, contrastAlphaBoost: 0.08)
  // White fails contrast on the light dark-mode accent (design §3.12).
  public static let onAccent = dynamic(light: 0xFFFFFF, dark: 0x0F1115)
  public static let neutralBar = dynamic(
    light: 0xC7C7CC, dark: 0x48484A, lightContrast: 0xAEAEB2, darkContrast: 0x636366)

  private static func dynamic(
    light: UInt32, dark: UInt32, lightContrast: UInt32? = nil, darkContrast: UInt32? = nil
  ) -> Color {
    Color(
      uiColor: UIColor { traits in
        let high = traits.accessibilityContrast == .high
        if traits.userInterfaceStyle == .dark {
          return rgb(high ? (darkContrast ?? dark) : dark)
        }
        return rgb(high ? (lightContrast ?? light) : light)
      })
  }

  private static func dynamic(
    light: UInt32, dark: UInt32, lightAlpha: CGFloat, darkAlpha: CGFloat,
    contrastAlphaBoost: CGFloat
  ) -> Color {
    Color(
      uiColor: UIColor { traits in
        let boost = traits.accessibilityContrast == .high ? contrastAlphaBoost : 0
        if traits.userInterfaceStyle == .dark {
          return rgb(dark, alpha: darkAlpha + boost)
        }
        return rgb(light, alpha: lightAlpha + boost)
      })
  }

  private static func rgb(_ hex: UInt32, alpha: CGFloat = 1) -> UIColor {
    UIColor(
      red: CGFloat((hex >> 16) & 0xFF) / 255,
      green: CGFloat((hex >> 8) & 0xFF) / 255,
      blue: CGFloat(hex & 0xFF) / 255,
      alpha: alpha)
  }
}
