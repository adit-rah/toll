import UIKit

/// The placeholder mark from `toll-brand-tbd.md` (a white ring on near-black), drawn in code so the
/// extension carries no asset until the identity exists.
enum ShieldIcon {
  static let accent = UIColor { traits in
    traits.userInterfaceStyle == .dark
      ? UIColor(red: 0x8F / 255, green: 0xB4 / 255, blue: 0xE3 / 255, alpha: 1)
      : UIColor(red: 0x3A / 255, green: 0x6E / 255, blue: 0xA5 / 255, alpha: 1)
  }

  static let image: UIImage = {
    let size = CGSize(width: 72, height: 72)
    return UIGraphicsImageRenderer(size: size).image { _ in
      UIColor(red: 0x1C / 255, green: 0x1C / 255, blue: 0x1E / 255, alpha: 1).setFill()
      UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 18).fill()
      let ring = UIBezierPath(ovalIn: CGRect(x: 24, y: 24, width: 24, height: 24))
      ring.lineWidth = 4
      UIColor.white.setStroke()
      ring.stroke()
    }
  }()
}
