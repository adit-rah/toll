import Foundation

/// A local wall-clock time of day, encoded "HH:mm" to match the server.
public struct ClockTime: Codable, Hashable, Sendable, Comparable {
  public var hour: Int
  public var minute: Int

  public init(hour: Int, minute: Int = 0) {
    self.hour = hour
    self.minute = minute
  }

  public var minuteOfDay: Int { hour * 60 + minute }

  public init(from decoder: Decoder) throws {
    let text = try decoder.singleValueContainer().decode(String.self)
    let parts = text.split(separator: ":").compactMap { Int($0) }
    guard parts.count == 2, (0..<24).contains(parts[0]), (0..<60).contains(parts[1]) else {
      throw DecodingError.dataCorrupted(
        .init(codingPath: decoder.codingPath, debugDescription: text))
    }
    self.init(hour: parts[0], minute: parts[1])
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(String(format: "%02d:%02d", hour, minute))
  }

  public static func < (lhs: ClockTime, rhs: ClockTime) -> Bool {
    lhs.minuteOfDay < rhs.minuteOfDay
  }
}

/// ISO weekday numbering (Monday = 1), matching the server and the Week definition in spec §4.
public enum Weekday: Int, Codable, CaseIterable, Sendable, Comparable {
  case monday = 1
  case tuesday, wednesday, thursday, friday, saturday, sunday

  public static let all = Set(Weekday.allCases)
  public static let workweek: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]

  /// From `Calendar.component(.weekday)`, where Sunday = 1.
  public init(gregorian value: Int) {
    self = Weekday(rawValue: (value + 5) % 7 + 1) ?? .monday
  }

  public var previous: Weekday { Weekday(rawValue: rawValue == 1 ? 7 : rawValue - 1) ?? .sunday }

  public static func < (lhs: Weekday, rhs: Weekday) -> Bool { lhs.rawValue < rhs.rawValue }
}
