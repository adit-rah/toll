import SwiftUI
import TollCore
import UIKit

/// Design §2.3. Every colour on screen comes from here so the placeholder accent swaps in one place.
public enum TollColor {
  public static let bg = Color(uiColor: .systemBackground)
  public static let bgGrouped = Color(uiColor: .systemGroupedBackground)
  public static let surface = Color(uiColor: .secondarySystemGroupedBackground)
  public static let surfaceRaised = Color(uiColor: .tertiarySystemGroupedBackground)
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

  public static let heat1 = dynamic(light: 0xE9EEF5, dark: 0x1F2A38)
  public static let heat2 = dynamic(light: 0xBDCEE1, dark: 0x3B4C63)
  public static let heat3 = dynamic(light: 0x92AECD, dark: 0x576F8D)
  public static let heat4 = dynamic(light: 0x668EB9, dark: 0x7391B8)
  public static let heat5 = dynamic(light: 0x3A6EA5, dark: 0x8FB4E3)
  public static let heat = [heat1, heat2, heat3, heat4, heat5]

  public static let level1 = dynamic(
    light: 0x2E8B6E, dark: 0x5FC3A3, lightContrast: 0x22705A, darkContrast: 0x7AD4B7)
  public static let level2 = dynamic(
    light: 0xC98A1B, dark: 0xE0B35B, lightContrast: 0x9E6A0F, darkContrast: 0xEBC57A)
  public static let level3 = dynamic(
    light: 0xB8532C, dark: 0xE08466, lightContrast: 0x96401F, darkContrast: 0xEC9C82)

  // Avatars keep one palette in both appearances, like a photo would (design §3.17).
  public static let avatarInitial = Color(uiColor: rgb(0x3A3A3C))
  public static let avatarTones: [Color] = avatarHexes.map { Color(uiColor: rgb($0)) }
  private static let avatarHexes: [UInt32] = [
    0xD9E3EC, 0xE4DCEA, 0xDDE8DC, 0xEDE2D3, 0xE8D9D9, 0xD8E6E6,
  ]

  /// FNV-1a over UTF-8 rather than `hashValue`, which is seeded per launch and would recolour avatars.
  public static func avatarTone(for handle: String) -> Color {
    var hash: UInt32 = 2_166_136_261
    for byte in handle.lowercased().utf8 {
      hash ^= UInt32(byte)
      hash = hash &* 16_777_619
    }
    return avatarTones[Int(hash % UInt32(avatarTones.count))]
  }

  public static func level(_ level: StatusLevel) -> Color {
    switch level {
    case .fewer: level1
    case .usual: level2
    case .more: level3
    }
  }

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
