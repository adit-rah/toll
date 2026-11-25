import SwiftUI
import UIKit

/// Dusk's palette: the design canvas's tokens (sticky note s4), dark first (decisions D36), made
/// calmer for the eyes (design §2.3): no pure white or black anywhere, a warm paper page in light, a
/// warm near-black in dark, and text a little softer than the extremes. Every colour on screen comes
/// from here; light mode is worked out from the same names. Increase Contrast takes text back to the
/// strong values.
public enum TollColor {
  public static let bg = dynamic(light: 0xECE9E2, dark: 0x131210)
  /// Cards and rows; sheets. A gentle step from the page, never white.
  public static let surface = dynamic(light: 0xF4F2ED, dark: 0x1C1A17)
  /// Icon tiles, progress tracks, the Apple tile, disabled buttons.
  public static let surfaceRaised = dynamic(light: 0xE3E0D8, dark: 0x25231F)
  /// Hairlines between rows.
  public static let separator = dynamic(light: 0xDAD6CD, dark: 0x2D2B27)
  /// Chart bars that are not tonight, the sheet grabber, dashed empty slots.
  public static let bar = dynamic(light: 0xD0CCC2, dark: 0x35332E)

  public static let label = dynamic(
    light: 0x25272B, dark: 0xE4E0D8, lightContrast: 0x141518, darkContrast: 0xF3F1EC)
  public static let label2 = dynamic(
    light: 0x575A60, dark: 0xA6A198, lightContrast: 0x45484D, darkContrast: 0xBDB9B1)
  /// Quiet marks and outlines (empty pips, dashed slots), so at least 3:1 on the page and cards.
  public static let label3 = dynamic(
    light: 0x7C7F85, dark: 0x77736B, lightContrast: 0x5F6268, darkContrast: 0x8E8A83)
  /// A number going the right way (fewer stops).
  public static let ok = dynamic(light: 0x2A7454, dark: 0x86C9A9)
  /// Over a limit, and deleting.
  public static let warn = dynamic(light: 0x9C4824, dark: 0xEE9E74)

  /// Amber. Light mode darkens it so text on the page stays above 4.5:1; increased contrast goes
  /// further.
  public static let accent = dynamic(
    light: 0x845810, dark: 0xE6B66C, lightContrast: 0x6E480F, darkContrast: 0xF2CD91)
  /// The amber at 14% behind a leading icon or "On now".
  public static let accentSoft = tint(light: 0x845810, dark: 0xE6B66C, alpha: 0.14)
  /// The warn colour at 12% behind "Delete block".
  public static let warnSoft = tint(light: 0x9C4824, dark: 0xEE9E74, alpha: 0.12)
  /// Text on amber: the light page's paper rather than white.
  public static let onAccent = dynamic(light: 0xF6F4EF, dark: 0x1C1408)

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

  /// A see-through tint; increased contrast makes it 8 points stronger.
  private static func tint(light: UInt32, dark: UInt32, alpha: CGFloat) -> Color {
    Color(
      uiColor: UIColor { traits in
        let alpha = alpha + (traits.accessibilityContrast == .high ? 0.08 : 0)
        return rgb(traits.userInterfaceStyle == .dark ? dark : light, alpha: alpha)
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
