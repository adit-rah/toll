import SwiftUI
import UIKit

/// Dusk's palette (the design canvas; decisions D36): dark first, warm grays, one amber accent. Light
/// values come from the canvas's *Home · light*. Every colour on screen comes from here.
public enum TollColor {
  public static let bg = dynamic(light: 0xF6F5F1, dark: 0x0D1015)
  /// Grouped lists sit on the page colour; cards carry the grouping.
  public static let bgGrouped = bg
  /// Cards and rows.
  public static let surface = dynamic(light: 0xFFFFFF, dark: 0x161A21)
  /// Selected rows, picker highlights, progress tracks.
  public static let surfaceRaised = dynamic(light: 0xEDEBE5, dark: 0x1F242C)
  /// Disabled buttons and switched-off controls.
  public static let fill = dynamic(light: 0xE3E1DA, dark: 0x2C323C)

  public static let label = dynamic(light: 0x1A1C20, dark: 0xEEECE6)
  public static let label2 = dynamic(light: 0x5B6068, dark: 0xA2A8B2)
  public static let label3 = dynamic(light: 0x9A9EA5, dark: 0x646B76)
  public static let separator = dynamic(light: 0xD9D6CE, dark: 0x262B34)
  public static let destructive = Color(uiColor: .systemRed)
  /// A number going the right way (fewer stops, less phone after bedtime).
  public static let positive = dynamic(light: 0x2E7D5B, dark: 0x5FC3A3)

  /// Amber. Light mode darkens it so text on the page stays above 4.5:1; increased contrast goes
  /// further.
  public static let accent = dynamic(
    light: 0x8E5E14, dark: 0xE9B96E, lightContrast: 0x6E480F, darkContrast: 0xF2CD91)
  public static let accentSoft = dynamic(
    light: 0xD9A24A, dark: 0xE9B96E, lightAlpha: 0.16, darkAlpha: 0.14, contrastAlphaBoost: 0.08)
  /// Dark text on the light amber; white on the dark amber.
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
