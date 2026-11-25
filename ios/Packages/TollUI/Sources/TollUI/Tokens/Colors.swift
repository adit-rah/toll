import SwiftUI
import UIKit

/// Dusk's palette: the design canvas's tokens (sticky note s4), dark first (decisions D36), with no
/// large bright area in either appearance (design §2.3). Light mode is warm paper: page and cards
/// near 80% luminance, cards a step darker than the page and edged with a hairline, never white.
/// Text stays strong in both. Every colour on screen comes from here; Increase Contrast goes further.
public enum TollColor {
  public static let bg = dynamic(light: 0xEDEAE4, dark: 0x131210)
  /// Cards and rows; sheets. Never brighter than the page (`tollSurface` adds the hairline).
  public static let surface = dynamic(light: 0xE6E3DC, dark: 0x1C1A17)
  /// Icon tiles, progress tracks, the Apple tile, disabled buttons.
  public static let surfaceRaised = dynamic(light: 0xDAD6CE, dark: 0x25231F)
  /// Hairlines between rows, and around cards.
  public static let separator = dynamic(light: 0xCFCAC0, dark: 0x2D2B27)
  /// Chart bars that are not tonight, the sheet grabber, dashed empty slots.
  public static let bar = dynamic(light: 0xC6C1B6, dark: 0x35332E)

  /// Body text: 13:1 or more on every surface.
  public static let label = dynamic(
    light: 0x1A1C20, dark: 0xEEECE6, lightContrast: 0x0E0F11, darkContrast: 0xF7F5F0)
  /// Secondary text: 5.4:1 or more on every surface.
  public static let label2 = dynamic(
    light: 0x4F5258, dark: 0xAAA69E, lightContrast: 0x3F4247, darkContrast: 0xC2BEB6)
  /// Marks, not text: chevrons, empty pips, outlines, dashed slots. At least 3:1, so never used
  /// for words someone needs to read.
  public static let label3 = dynamic(
    light: 0x72757B, dark: 0x77736B, lightContrast: 0x5B5E64, darkContrast: 0x8E8A83)
  /// A number going the right way (fewer stops).
  public static let ok = dynamic(light: 0x256B4D, dark: 0x86C9A9)
  /// Over a limit, and deleting.
  public static let warn = dynamic(light: 0x8C3F1F, dark: 0xEE9E74)

  /// Amber. Light mode darkens it so text on its soft tint stays above 4.5:1; increased contrast
  /// goes further.
  public static let accent = dynamic(
    light: 0x744C0B, dark: 0xE9B96E, lightContrast: 0x5E3D09, darkContrast: 0xF2CD91)
  /// The amber at 14% behind a leading icon or "On now".
  public static let accentSoft = tint(light: 0x744C0B, dark: 0xE9B96E, alpha: 0.14)
  /// The warn colour at 12% behind "Delete block".
  public static let warnSoft = tint(light: 0x8C3F1F, dark: 0xEE9E74, alpha: 0.12)
  /// Text on amber: warm paper rather than white.
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
