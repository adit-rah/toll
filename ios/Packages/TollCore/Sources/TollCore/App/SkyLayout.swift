import Foundation

/// Where Your sky's stars land on screen, and which one a tap is nearest. The drawing and the tap
/// share this, so a tap finds the star the eye sees.
public struct SkyLayout: Equatable, Sendable {
  public var scale: Double
  public var originX: Double
  public var originY: Double

  /// Fits `bounds` (the drawing's frame, in widths of the sky) inside a field of points, centred.
  public init(
    bounds: Sky.Bounds, fieldX: Double, fieldY: Double, fieldWidth: Double, fieldHeight: Double
  ) {
    let scale = min(fieldWidth / bounds.width, fieldHeight / max(bounds.height, 0.001))
    self.scale = scale
    originX = fieldX + (fieldWidth - bounds.width * scale) / 2 - bounds.x * scale
    originY = fieldY + (fieldHeight - bounds.height * scale) / 2 - bounds.y * scale
  }

  public func x(_ x: Double) -> Double { originX + x * scale }
  public func y(_ y: Double) -> Double { originY + y * scale }

  /// The lit star nearest a tap, if one is within `radius` points (22: a 44 pt target).
  public func nearest(_ stars: [Sky.Star], x tapX: Double, y tapY: Double, radius: Double = 22)
    -> Int?
  {
    var best: (index: Int, distance: Double)?
    for (index, star) in stars.enumerated() {
      let distance = hypot(x(star.x) - tapX, y(star.y) - tapY)
      guard distance <= radius, distance < best?.distance ?? .infinity else { continue }
      best = (index, distance)
    }
    return best?.index
  }
}

/// The sky's atmosphere: a fixed dust of faint points and the Milky Way's band, the same on every
/// open. They are not the catalogue's stars and say nothing about what's left (D79): unlit stars are
/// never drawn. Positions run 0 to 1 across and down the whole sky.
public enum SkyDust {
  public struct Mote: Equatable, Sendable {
    public var x: Double
    public var y: Double
    /// Its opacity, faint to very faint.
    public var brightness: Double
    /// Its radius, in points.
    public var size: Double
  }

  /// The Milky Way: a soft band from low on the left to high on the right.
  public static let band = (from: (x: -0.1, y: 0.86), to: (x: 1.1, y: 0.06), width: 0.30)

  /// The dust, made once from a fixed seed.
  public static let motes: [Mote] = make(seed: 0x00D5_5C1E, count: 260, inBand: 0.45)

  /// `inBand` of the motes gather along the band, as its grain; the rest are spread evenly.
  static func make(seed: UInt64, count: Int, inBand: Double) -> [Mote] {
    var random = SplitMix(seed: seed)
    let banded = Int(Double(count) * inBand)
    return (0..<count).map { index in
      var x = random.unit()
      var y = random.unit()
      if index < banded {
        let along = random.unit()
        // A sum of three draws is a soft bell: most grain near the band's spine.
        let across = (random.unit() + random.unit() + random.unit() - 1.5) / 1.5 * band.width / 2
        let dx = band.to.x - band.from.x
        let dy = band.to.y - band.from.y
        let length = hypot(dx, dy)
        x = band.from.x + dx * along - dy / length * across
        y = band.from.y + dy * along + dx / length * across
      }
      let faint = random.unit()
      return Mote(
        x: x, y: y, brightness: 0.07 + 0.28 * faint * faint, size: 0.35 + 0.5 * random.unit())
    }
    .filter { (0...1).contains($0.x) && (0...1).contains($0.y) }
  }

  /// How far a point lies from the band's spine, in the sky's units.
  static func distanceFromBand(x: Double, y: Double) -> Double {
    let dx = band.to.x - band.from.x
    let dy = band.to.y - band.from.y
    return abs(dy * (x - band.from.x) - dx * (y - band.from.y)) / hypot(dx, dy)
  }
}

/// A small seeded generator (SplitMix64), so the dust is the same on every phone and every open.
struct SplitMix {
  var state: UInt64

  init(seed: UInt64) { state = seed }

  mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    return z ^ (z >> 31)
  }

  /// A number from 0 up to 1.
  mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }
}
