import UIKit

/// Dusk's block screen colours and mark (the design canvas: amber on near-black, a moon), drawn in
/// code so the extension carries no asset. Always dark: the block screen is mostly seen at night.
enum ShieldIcon {
  static let background = rgb(0x0D1015)
  static let label = rgb(0xEEECE6)
  static let secondaryLabel = rgb(0xA2A8B2)
  static let accent = rgb(0xE9B96E)
  static let onAccent = rgb(0x1C1408)

  /// An amber crescent on a soft amber tile.
  static let image: UIImage = {
    let size = CGSize(width: 72, height: 72)
    return UIGraphicsImageRenderer(size: size).image { _ in
      accent.withAlphaComponent(0.14).setFill()
      UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 20).fill()
      // A disc with a smaller one cut out of its upper right: clip everything but the cut, then fill.
      let cut = UIBezierPath(rect: CGRect(origin: .zero, size: size))
      cut.append(UIBezierPath(ovalIn: CGRect(x: 30, y: 10, width: 32, height: 32)))
      cut.usesEvenOddFillRule = true
      cut.addClip()
      accent.setFill()
      UIBezierPath(ovalIn: CGRect(x: 18, y: 18, width: 36, height: 36)).fill()
    }
  }()

  private static func rgb(_ hex: UInt32) -> UIColor {
    UIColor(
      red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
      blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
  }
}
