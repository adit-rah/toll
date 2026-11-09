import Foundation

/// A Toll day: from `gate.dayResetHour` local to the same hour the next day (spec §4), named by its date.
/// Encoded "YYYY-MM-DD" to match the server's rollup keys.
public struct TollDay: Codable, Hashable, Sendable, Comparable, CustomStringConvertible {
  public let year: Int
  public let month: Int
  public let day: Int

  public init(year: Int, month: Int, day: Int) {
    self.year = year
    self.month = month
    self.day = day
  }

  public init?(_ text: String) {
    let parts = text.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3 else { return nil }
    self.init(year: parts[0], month: parts[1], day: parts[2])
  }

  public var description: String { String(format: "%04d-%02d-%02d", year, month, day) }

  public init(from decoder: Decoder) throws {
    let text = try decoder.singleValueContainer().decode(String.self)
    guard let value = TollDay(text) else {
      throw DecodingError.dataCorrupted(
        .init(codingPath: decoder.codingPath, debugDescription: text))
    }
    self = value
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(description)
  }

  public static func < (lhs: TollDay, rhs: TollDay) -> Bool {
    (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
  }

  // Calendar arithmetic in UTC at noon: date names only, so no time zone or DST can shift them.
  private static let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
    return calendar
  }()

  private var utcNoon: Date {
    TollDay.utc.date(from: DateComponents(year: year, month: month, day: day, hour: 12))
      ?? .distantPast
  }

  public func adding(days: Int) -> TollDay {
    let date = TollDay.utc.date(byAdding: .day, value: days, to: utcNoon) ?? utcNoon
    let c = TollDay.utc.dateComponents([.year, .month, .day], from: date)
    return TollDay(year: c.year ?? year, month: c.month ?? month, day: c.day ?? day)
  }

  public func days(until other: TollDay) -> Int {
    TollDay.utc.dateComponents([.day], from: utcNoon, to: other.utcNoon).day ?? 0
  }

  public var weekday: Weekday { Weekday(gregorian: TollDay.utc.component(.weekday, from: utcNoon)) }

  /// The Monday that names this day's week.
  public var weekStart: TollDay { adding(days: 1 - weekday.rawValue) }
}
