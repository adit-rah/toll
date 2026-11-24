import Foundation

extension Copy {
  /// Insights (the design canvas): everything from the log on this phone (D24).
  public enum Insights {
    public static let title = "Your nights"
    /// The ranges say their length, so "Week" isn't read as Your sleep's Monday-to-Sunday week.
    public static let week = "7 days"
    public static let month = "30 days"
    public static let all = "All time"
    /// About the person, not the app's work (D65): the hours the apps stayed closed.
    public static let hoursLabel = "phone-free"
    public static func hours(_ hours: Int) -> String { "\(hours) h" }
    public static let when = "When you put it down"
    public static func mostAt(_ hour: String) -> String { "Most at \(hour)" }
    /// "midnight" for 0 on 12-hour phones, as the canvas writes it; otherwise the short time.
    public static func hourName(_ hour: Int, in calendar: Calendar = .current) -> String {
      let short = time(ClockTime(hour: hour), in: calendar, short: true)
      return hour == 0 && short.contains("am") ? "midnight" : short
    }
    public static let empty = "Nothing yet. Your nights show here after the first one."
  }
}
