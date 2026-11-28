/// One person's adapter: the precision matrix Λ (row by row), the vector b, the usable nights, and
/// whether the insight showed after the last of them (an insight showing keeps a laxer test, #117).
/// Since schema 3 (#154) it also carries the calendar week of the last usable night, so the usual
/// time can wander between weeks, and the sums the noise's scale is learned from
/// (`SleepModel+Wander.swift`). The app keeps the night records too, so a new base can rebuild this
/// in one pass.
public struct PersonState: Codable, Sendable, Equatable {
  public var precision: [Double]
  public var b: [Double]
  public var nights: Int
  public var shown: Bool
  /// Whole weeks since 2001-01-01 (a Monday) of the last usable night; nil before one.
  public var week: Int?
  /// Forgetting sums over past weeks: squared week sums, each week's sum times the week before's,
  /// and their nights.
  public var scaleSum: Double
  public var scaleCross: Double
  public var scaleNights: Double
  /// This week's sum of standardized residuals and its nights, and the week before's sum.
  public var weekSum: Double
  public var weekNights: Double
  public var lastWeekSum: Double

  public init(
    precision: [Double], b: [Double], nights: Int, shown: Bool = false, week: Int? = nil,
    scaleSum: Double = 0, scaleCross: Double = 0, scaleNights: Double = 0, weekSum: Double = 0,
    weekNights: Double = 0, lastWeekSum: Double = 0
  ) {
    self.precision = precision
    self.b = b
    self.nights = nights
    self.shown = shown
    self.week = week
    self.scaleSum = scaleSum
    self.scaleCross = scaleCross
    self.scaleNights = scaleNights
    self.weekSum = weekSum
    self.weekNights = weekNights
    self.lastWeekSum = lastWeekSum
  }

  enum CodingKeys: String, CodingKey {
    case precision, b, nights, shown, week
    case scaleSum = "scale_sum"
    case scaleCross = "scale_cross"
    case scaleNights = "scale_nights"
    case weekSum = "week_sum"
    case weekNights = "week_nights"
    case lastWeekSum = "last_week_sum"
  }

  /// A state written before `shown` (sleep-model.v0's caches) reads as not shown, and one written
  /// before schema 3 as no week and no sums.
  public init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    precision = try c.decode([Double].self, forKey: .precision)
    b = try c.decode([Double].self, forKey: .b)
    nights = try c.decode(Int.self, forKey: .nights)
    shown = try c.decodeIfPresent(Bool.self, forKey: .shown) ?? false
    week = try c.decodeIfPresent(Int.self, forKey: .week)
    func number(_ key: CodingKeys) throws -> Double {
      try c.decodeIfPresent(Double.self, forKey: key) ?? 0
    }
    scaleSum = try number(.scaleSum)
    scaleCross = try number(.scaleCross)
    scaleNights = try number(.scaleNights)
    weekSum = try number(.weekSum)
    weekNights = try number(.weekNights)
    lastWeekSum = try number(.lastWeekSum)
  }
}
