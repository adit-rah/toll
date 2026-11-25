import SwiftUI
import TollCore

/// Your sky's colours (design §2.3, "Your sky"). The sky is the same night in both appearances, so
/// none of these follow light or dark: only the land under it, drawn in `TollColor.bg`, does.
public enum SkyColor {
  /// A night's gradient, top to horizon, and the glow that rises from the horizon.
  public struct Palette: Sendable {
    public let stops: [Gradient.Stop]
    public let glow: Color
    /// How far the glow reaches up the sky, as a share of its height.
    public let glowReach: CGFloat
  }

  /// The three lights (`SkyLight`): fixed, with nothing moving between them.
  public static func palette(_ light: SkyLight) -> Palette {
    switch light {
    case .evening:
      Palette(
        stops: [
          .init(color: hex(0x05070F), location: 0), .init(color: hex(0x0C1030), location: 0.42),
          .init(color: hex(0x1F1D47), location: 0.74), .init(color: hex(0x3A2B4E), location: 1),
        ],
        // The accent amber, low: the dusk the app is named for.
        glow: hex(0xE9B96E).opacity(0.42), glowReach: 0.7)
    case .night:
      Palette(
        stops: [
          .init(color: hex(0x04060D), location: 0), .init(color: hex(0x0A0E26), location: 0.5),
          .init(color: hex(0x141A3B), location: 1),
        ],
        glow: hex(0x2A3366).opacity(0.35), glowReach: 0.35)
    case .morning:
      Palette(
        stops: [
          .init(color: hex(0x070A18), location: 0), .init(color: hex(0x131B3D), location: 0.45),
          .init(color: hex(0x2C3A5E), location: 0.8), .init(color: hex(0x4A5A7A), location: 1),
        ],
        glow: hex(0xB4C2D6).opacity(0.45), glowReach: 0.5)
    }
  }

  /// Lit stars, before their B–V tint: the dark `label`.
  public static let star = hex(0xEEECE6)
  /// Figure lines and constellation names: a faint cool grey, so the sky reads as a sky.
  public static let line = hex(0x646B76)
  /// Lines a tap brings forward (`SkyFocus`): one step up, a cool grey.
  public static let lineBright = hex(0xA2A8B2)
  /// Names a tap brings forward: the sky's text, legible on every light.
  public static let nameBright = hex(0xEEECE6)
  /// The newest star and its glow: the dark accent.
  public static let newest = hex(0xE9B96E)
  /// The dust and the Milky Way: starlight at low opacity.
  public static let dust = hex(0xDDE3F0)
  /// The moon's lit face, and its earthshine at low opacity.
  public static let moon = hex(0xF1EEE4)
  /// Text set on the sky: the dark `label`.
  public static let text = hex(0xEEECE6)

  /// A star's colour from its B–V index (`StarColour`), subtly.
  public static func star(bv: Double) -> Color {
    let tint = StarColour.tint(bv: bv)
    return Color(red: tint.red, green: tint.green, blue: tint.blue)
  }

  static func hex(_ value: UInt32) -> Color {
    Color(
      red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255,
      blue: Double(value & 0xFF) / 255)
  }
}
