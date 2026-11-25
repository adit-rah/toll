import Foundation

/// The moon as it really was (Your sky): its age in the synodic month, worked out on the phone from
/// one known new moon and the mean month, so nothing is fetched. The mean month drifts from the true
/// one by up to about 14 hours, well inside a night.
public struct Moon: Equatable, Sendable {
  /// The mean synodic month, in days.
  static let month = 29.530588853
  /// A new moon: 6 January 2000, 18:14 UTC.
  static let knownNew = Date(timeIntervalSince1970: 947_182_440)

  /// Days since the last new moon, 0 up to `month`.
  public var age: Double
  /// Whether the lit side is on the right as seen from the night's place: a waxing moon is lit on
  /// the right north of the equator and on the left south of it.
  public var litOnRight: Bool

  public init(at date: Date, southern: Bool = false) {
    let days = date.timeIntervalSince(Self.knownNew) / 86_400
    let age = days.truncatingRemainder(dividingBy: Self.month)
    self.age = age < 0 ? age + Self.month : age
    litOnRight = (self.age < Self.month / 2) != southern
  }

  /// The share of the disc that is lit, 0 at new moon to 1 at full.
  public var fraction: Double { (1 - cos(phase)) / 2 }

  /// Growing toward full.
  public var waxing: Bool { age < Self.month / 2 }

  /// The phase angle, 0 at new moon, π at full.
  public var phase: Double { 2 * Double.pi * age / Self.month }

  /// Where the terminator crosses the disc's middle, in radii from the centre toward the lit limb:
  /// 1 at new moon (no light), 0 at the quarters, −1 at full (all light).
  public var terminator: Double { cos(phase) }

  /// Last night's moon: as it was at the most recent midnight, so a morning and the evening after
  /// it show the same night.
  public static func lastNight(before now: Date, calendar: Calendar, southern: Bool) -> Moon {
    Moon(at: calendar.startOfDay(for: now), southern: southern)
  }
}

/// The glow at Your sky's horizon, chosen by the phone's hour when the screen opens. Three fixed
/// lights with nothing moving between them; the hours are in `TollConfig.Sky`.
public enum SkyLight: String, CaseIterable, Sendable {
  /// A low amber glow, the dusk the app is named for.
  case evening
  /// Almost no glow.
  case night
  /// A cool, pale blue-grey.
  case morning

  public init(at date: Date, calendar: Calendar, config: TollConfig = .defaults) {
    let hour = calendar.component(.hour, from: date)
    let sky = config.sky
    func within(_ from: Int, _ to: Int) -> Bool {
      from <= to ? (from..<to).contains(hour) : hour >= from || hour < to
    }
    if within(sky.eveningFromHour, sky.nightFromHour) {
      self = .evening
    } else if within(sky.nightFromHour, sky.morningFromHour) {
      self = .night
    } else {
      self = .morning
    }
  }
}

/// A star's colour from its B–V index, as the eye sees it: blue-white below 0, white near 0.3, the
/// Sun's pale yellow at 0.65, orange-red past 1.4. Interpolated from approximate blackbody colours
/// for the temperatures those indexes stand for, then kept subtle so the sky stays calm.
public enum StarColour {
  /// B–V and its colour (red, green, blue, 0 to 1).
  static let table: [(bv: Double, rgb: (Double, Double, Double))] = [
    (-0.4, (0.61, 0.71, 1.00)),
    (-0.2, (0.69, 0.77, 1.00)),
    (0.0, (0.80, 0.85, 1.00)),
    (0.3, (0.93, 0.93, 1.00)),
    (0.65, (1.00, 0.95, 0.88)),
    (1.0, (1.00, 0.86, 0.70)),
    (1.5, (1.00, 0.77, 0.53)),
    (2.0, (1.00, 0.70, 0.42)),
  ]

  /// The full colour of a star of this index.
  public static func rgb(bv: Double) -> (red: Double, green: Double, blue: Double) {
    let clamped = min(max(bv, table[0].bv), table[table.count - 1].bv)
    let upper = table.firstIndex { $0.bv >= clamped } ?? table.count - 1
    let lower = max(0, upper - 1)
    let (a, b) = (table[lower], table[upper])
    let t = upper == lower ? 0 : (clamped - a.bv) / (b.bv - a.bv)
    return (
      a.rgb.0 + (b.rgb.0 - a.rgb.0) * t, a.rgb.1 + (b.rgb.1 - a.rgb.1) * t,
      a.rgb.2 + (b.rgb.2 - a.rgb.2) * t
    )
  }

  /// The colour drawn: `amount` of the star's own colour over the near-white of the page's text.
  public static func tint(bv: Double, amount: Double = 0.38) -> (
    red: Double, green: Double, blue: Double
  ) {
    // `SkyColor.star`, #EEECE6, so an untinted star is the colour every star was before.
    let base = (0.933, 0.925, 0.902)
    let colour = rgb(bv: bv)
    return (
      base.0 + (colour.red - base.0) * amount, base.1 + (colour.green - base.1) * amount,
      base.2 + (colour.blue - base.2) * amount
    )
  }
}
