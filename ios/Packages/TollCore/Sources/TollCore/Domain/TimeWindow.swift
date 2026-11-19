import Foundation

/// A daily window in local wall-clock times: the Sleep block's night, a Study block's 9 to 5. It may
/// cross midnight. Each occurrence's dates are worked out from the calendar it is given, so a time zone
/// change or a daylight-saving jump moves the window with the wall clock.
public struct TimeWindow: Codable, Hashable, Sendable {
  public var start: ClockTime
  public var end: ClockTime

  /// DeviceActivity refuses shorter intervals (spec §5).
  public static let minimumMinutes = 15

  public init(start: ClockTime, end: ClockTime) {
    self.start = start
    self.end = end
  }

  /// Setup's default: wake time minus `leadHours` (spec §7, §10).
  public init(wake: ClockTime, leadHours: Double) {
    let lead = Int((leadHours * 60).rounded())
    let minute = ((wake.minuteOfDay - lead) % 1440 + 1440) % 1440
    self.init(start: ClockTime(hour: minute / 60, minute: minute % 60), end: wake)
  }

  public var crossesMidnight: Bool { end <= start }

  /// Nominal length; a daylight-saving night is an hour longer or shorter.
  public var minutes: Int { (end.minuteOfDay - start.minuteOfDay + 1440) % 1440 }

  public var isValid: Bool { minutes >= Self.minimumMinutes }

  /// One occurrence: from this start to the end that follows it.
  public struct Night: Hashable, Sendable {
    public var start: Date
    public var end: Date

    public func contains(_ date: Date) -> Bool { start <= date && date < end }
  }

  /// The night that begins on the calendar day of `day`.
  public func night(startingOn day: Date, calendar: Calendar) -> Night? {
    guard isValid else { return nil }
    let dayStart = calendar.startOfDay(for: day)
    guard let startDate = Self.date(start, onDayStarting: dayStart, calendar: calendar),
      let endDay = crossesMidnight
        ? calendar.date(byAdding: .day, value: 1, to: dayStart) : dayStart,
      let endDate = Self.date(
        end, onDayStarting: calendar.startOfDay(for: endDay), calendar: calendar),
      endDate > startDate
    else { return nil }
    return Night(start: startDate, end: endDate)
  }

  public func night(containing date: Date, calendar: Calendar) -> Night? {
    nights(around: date, offsets: [0, -1], calendar: calendar).first { $0.contains(date) }
  }

  public func contains(_ date: Date, calendar: Calendar) -> Bool {
    night(containing: date, calendar: calendar) != nil
  }

  /// The latest night end at or before `date`.
  public func lastEnd(atOrBefore date: Date, calendar: Calendar) -> Date? {
    nights(around: date, offsets: [0, -1, -2], calendar: calendar).map(\.end).filter { $0 <= date }
      .max()
  }

  /// The earliest night start after `date`.
  public func nextStart(after date: Date, calendar: Calendar) -> Date? {
    nights(around: date, offsets: [0, 1, 2], calendar: calendar).map(\.start).filter { $0 > date }
      .min()
  }

  /// Every night end in (`after`, `through`], oldest first. Counting nights by their ends (spec §3).
  public func ends(after start: Date, through end: Date, calendar: Calendar) -> [Date] {
    guard start < end, let first = calendar.date(byAdding: .day, value: -1, to: start) else {
      return []
    }
    var result: [Date] = []
    var day = first
    while day <= end {
      if let night = night(startingOn: day, calendar: calendar), night.end > start, night.end <= end
      {
        result.append(night.end)
      }
      guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
      day = next
    }
    return result
  }

  private func nights(around date: Date, offsets: [Int], calendar: Calendar) -> [Night] {
    offsets.compactMap { offset in
      calendar.date(byAdding: .day, value: offset, to: date).flatMap {
        night(startingOn: $0, calendar: calendar)
      }
    }
  }

  /// A time that does not exist that day (skipped by daylight saving) becomes the first one that does;
  /// a time that happens twice is its first.
  static func date(_ time: ClockTime, onDayStarting dayStart: Date, calendar: Calendar) -> Date? {
    guard
      let date = calendar.nextDate(
        after: dayStart.addingTimeInterval(-1),
        matching: DateComponents(hour: time.hour, minute: time.minute, second: 0),
        matchingPolicy: .nextTime, repeatedTimePolicy: .first, direction: .forward),
      calendar.isDate(date, inSameDayAs: dayStart)
    else { return nil }
    return date
  }
}
