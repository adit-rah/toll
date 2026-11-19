import Foundation

/// Every user-facing line (MVP spec §7, §8). A fact, a number or a question; never an adjective about
/// the user. Each step of the build adds the lines its screens use.
public enum Copy {
  public static let middleDot = " · "

  /// In the user's own 12- or 24-hour format (spec §8).
  public static func time(_ date: Date, in calendar: Calendar = .current) -> String {
    date.formatted(
      Date.FormatStyle(
        date: .omitted, time: .shortened, calendar: calendar, timeZone: calendar.timeZone))
  }

  public static func time(_ clock: ClockTime, in calendar: Calendar = .current) -> String {
    let date = calendar.date(
      bySettingHour: clock.hour, minute: clock.minute, second: 0, of: Date(timeIntervalSince1970: 0)
    )
    return date.map { time($0, in: calendar) }
      ?? String(format: "%02d:%02d", clock.hour, clock.minute)
  }

  public static func window(_ window: TimeWindow, in calendar: Calendar = .current) -> String {
    "\(time(window.start, in: calendar)) to \(time(window.end, in: calendar))"
  }
}
