import Foundation

/// When a block's shield is on (spec §4, G-7a). Encoded the same way the server stores it.
public struct Schedule: Codable, Hashable, Sendable {
  public enum Kind: String, Codable, Sendable, CaseIterable {
    case always, nights, weekdays, custom
  }

  public var kind: Kind
  public var start: ClockTime
  public var end: ClockTime
  public var days: Set<Weekday>

  public init(kind: Kind, start: ClockTime, end: ClockTime, days: Set<Weekday>) {
    self.kind = kind
    self.start = start
    self.end = end
    self.days = days
  }

  public static let always = Schedule(
    kind: .always, start: ClockTime(hour: 0), end: ClockTime(hour: 0), days: Weekday.all)

  public static func preset(_ kind: Kind, presets: SchedulePresets = SchedulePresets()) -> Schedule
  {
    switch kind {
    case .always, .custom: return .always
    case .nights:
      return Schedule(
        kind: .nights, start: presets.nights.start, end: presets.nights.end,
        days: presets.nights.days)
    case .weekdays:
      return Schedule(
        kind: .weekdays, start: presets.weekdays.start, end: presets.weekdays.end,
        days: presets.weekdays.days)
    }
  }

  public static func custom(start: ClockTime, end: ClockTime, days: Set<Weekday>) -> Schedule {
    Schedule(kind: .custom, start: start, end: end, days: days)
  }

  public var crossesMidnight: Bool { kind != .always && end <= start && end != start }

  /// A window belongs to the day it starts on, so "nights on Friday" runs Friday 23:00 to Saturday 07:00.
  public func isActive(at date: Date, in math: DayMath) -> Bool {
    if kind == .always { return true }
    let minute = math.minuteOfDay(of: date)
    let weekday = math.weekday(of: date)
    if start == end { return days.contains(weekday) }
    if start < end {
      return days.contains(weekday) && minute >= start.minuteOfDay && minute < end.minuteOfDay
    }
    return (days.contains(weekday) && minute >= start.minuteOfDay)
      || (days.contains(weekday.previous) && minute < end.minuteOfDay)
  }
}
