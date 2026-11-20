import Foundation

/// Every user-facing line (MVP spec §7, §8). A fact, a number or a question; never an adjective about
/// the user. Each step of the build adds the lines its screens use.
public enum Copy {
  public static let middleDot = " · "

  /// In the user's own 12- or 24-hour format (spec §8), with "am" and "pm" set lowercase as the canvas
  /// draws them. `short` drops ":00" from a whole hour on 12-hour phones ("9 am").
  public static func time(_ date: Date, in calendar: Calendar = .current, short: Bool = false)
    -> String
  {
    // A calendar made in code carries the root locale; only a real one overrides the phone's.
    let locale = calendar.locale.flatMap { $0.identifier.isEmpty ? nil : $0 } ?? .current
    let twelveHour =
      DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: locale)?.contains("a")
      ?? false
    let wholeHour = calendar.component(.minute, from: date) == 0
    let formatter = DateFormatter()
    formatter.locale = locale
    formatter.calendar = calendar
    formatter.timeZone = calendar.timeZone
    formatter.setLocalizedDateFormatFromTemplate(short && twelveHour && wholeHour ? "j" : "jmm")
    if locale.language.languageCode?.identifier == "en" {
      formatter.amSymbol = "am"
      formatter.pmSymbol = "pm"
    }
    return formatter.string(from: date)
  }

  public static func time(_ clock: ClockTime, in calendar: Calendar = .current, short: Bool = false)
    -> String
  {
    let date = calendar.date(
      bySettingHour: clock.hour, minute: clock.minute, second: 0, of: Date(timeIntervalSince1970: 0)
    )
    return date.map { time($0, in: calendar, short: short) }
      ?? String(format: "%02d:%02d", clock.hour, clock.minute)
  }

  public static func window(_ window: TimeWindow, in calendar: Calendar = .current) -> String {
    "\(time(window.start, in: calendar)) to \(time(window.end, in: calendar))"
  }
}
