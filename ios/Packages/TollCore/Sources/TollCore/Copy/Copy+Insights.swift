import Foundation

extension Copy {
  /// Insights (the design canvas): everything from the log on this phone (D24).
  public enum Insights {
    public static let title = "Your nights"
    public static let week = "Week"
    public static let month = "Month"
    public static let all = "All"
    public static func nightsSince(_ day: String) -> String { "nights blocked since \(day)" }
    public static let hoursLabel = "blocked at night"
    public static func hours(_ hours: Int) -> String { "\(hours) h" }
    public static let stopped = "Times it stopped you"
    public static func change(_ percent: Int) -> String {
      percent <= 0 ? "▼ \(-percent)% since week 1" : "▲ \(percent)% since week 1"
    }
    public static func weekLabel(_ n: Int) -> String { "Week \(n)" }
    public static let when = "When it stopped you"
    public static func mostAt(_ hour: String) -> String { "Most at \(hour)" }
    /// "midnight" for 0 on 12-hour phones, as the canvas writes it; otherwise the short time.
    public static func hourName(_ hour: Int, in calendar: Calendar = .current) -> String {
      let short = time(ClockTime(hour: hour), in: calendar, short: true)
      return hour == 0 && short.contains("am") ? "midnight" : short
    }
    public static let empty = "Nothing yet. Your nights show here after the first one."
  }
}
