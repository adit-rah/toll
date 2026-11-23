import TollCore
import UIKit

/// Dusk's block screen colours and mark (the design canvas: amber on near-black, a moon), drawn in
/// code so the extension carries no asset. Always dark: the block screen is mostly seen at night.
enum ShieldIcon {
  static let background = rgb(0x0D1015)
  static let label = rgb(0xEEECE6)
  static let secondaryLabel = rgb(0xA2A8B2)
  static let accent = rgb(0xE9B96E)
  static let onAccent = rgb(0x1C1408)

  /// The block's own symbol on a soft amber tile, with the week's pauses as dots under it (#75, D67):
  /// the moon only for Sleep, so a Study block shows a book. One draw, in milliseconds.
  static func image(kind: Block.Kind, left: Int, max: Int) -> UIImage {
    let size = CGSize(width: 72, height: 88)
    return UIGraphicsImageRenderer(size: size).image { _ in
      accent.withAlphaComponent(0.14).setFill()
      UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 20).fill()
      let config = UIImage.SymbolConfiguration(pointSize: 30, weight: .medium)
      if let symbol = UIImage(systemName: symbolName(kind), withConfiguration: config)?
        .withTintColor(accent, renderingMode: .alwaysOriginal)
      {
        let origin = CGPoint(
          x: (size.width - symbol.size.width) / 2, y: 36 - symbol.size.height / 2)
        symbol.draw(at: origin)
      }
      // The supply, as Home and the door draw it: filled for each left, outlined for each used.
      let dot: CGFloat = 9
      let gap: CGFloat = 5
      let count = Swift.max(0, max)
      let width = CGFloat(count) * dot + CGFloat(Swift.max(0, count - 1)) * gap
      for index in 0..<count {
        let rect = CGRect(
          x: (size.width - width) / 2 + CGFloat(index) * (dot + gap), y: 66, width: dot,
          height: dot)
        let path = UIBezierPath(ovalIn: rect.insetBy(dx: 0.75, dy: 0.75))
        if index < left {
          accent.setFill()
          path.fill()
        } else {
          secondaryLabel.setStroke()
          path.lineWidth = 1.5
          path.stroke()
        }
      }
    }
  }

  /// Design §2.6's symbol for each kind of block (`TollSymbol.block`); the extension doesn't load
  /// TollUI.
  private static func symbolName(_ kind: Block.Kind) -> String {
    switch kind {
    case .sleep: "moon"
    case .study: "book"
    case .work: "briefcase"
    case .gym: "bolt"
    case .other: "ellipsis"
    }
  }

  private static func rgb(_ hex: UInt32) -> UIColor {
    UIColor(
      red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
      blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
  }
}
