import SwiftUI
import UIKit

/// Dusk's palette: the design canvas's tokens (sticky note s4), dark first (decisions D36). Every
/// colour on screen comes from here; light mode is worked out from the same names.
public enum TollColor {
  public static let bg = dynamic(light: 0xF6F5F1, dark: 0x0D1015)
  /// Cards and rows; sheets.
  public static let surface = dynamic(light: 0xFFFFFF, dark: 0x161A21)
  /// Icon tiles, progress tracks, the Apple tile, disabled buttons.
  public static let surfaceRaised = dynamic(light: 0xEDEBE5, dark: 0x1F242C)
  /// Hairlines between rows.
  public static let separator = dynamic(light: 0xE3E1DA, dark: 0x262B34)
  /// Chart bars that are not tonight, the sheet grabber, dashed empty slots.
  public static let bar = dynamic(light: 0xD9D6CE, dark: 0x2C323C)

  public static let label = dynamic(light: 0x1A1C20, dark: 0xEEECE6)
  public static let label2 = dynamic(light: 0x5B6068, dark: 0xA2A8B2)
  public static let label3 = dynamic(light: 0x9A9EA5, dark: 0x646B76)
  /// A number going the right way (fewer stops).
  public static let ok = dynamic(light: 0x2E7D5B, dark: 0x86C9A9)
  /// Over a limit, and deleting.
  public static let warn = dynamic(light: 0xB4542C, dark: 0xEE9E74)

  /// Amber. Light mode darkens it so text on the page stays above 4.5:1; increased contrast goes
  /// further.
  public static let accent = dynamic(
    light: 0x8E5E14, dark: 0xE9B96E, lightContrast: 0x6E480F, darkContrast: 0xF2CD91)
  /// The amber at 14% behind a leading icon or "On now".
  public static let accentSoft = tint(light: 0x8E5E14, dark: 0xE9B96E, alpha: 0.14)
  /// The warn colour at 12% behind "Delete block".
  public static let warnSoft = tint(light: 0xB4542C, dark: 0xEE9E74, alpha: 0.12)
  /// Text on amber.
  public static let onAccent = dynamic(light: 0xFFFFFF, dark: 0x1C1408)

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
