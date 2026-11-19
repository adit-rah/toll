import Foundation

/// A local wall-clock time of day, encoded "HH:mm" so the state file reads plainly.
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

extension ClockTime {
  /// Wraps past midnight either way.
  public func adding(minutes: Int) -> ClockTime {
    let total = ((minuteOfDay + minutes) % 1440 + 1440) % 1440
    return ClockTime(hour: total / 60, minute: total % 60)
  }

  public var components: DateComponents { DateComponents(hour: hour, minute: minute) }
}
