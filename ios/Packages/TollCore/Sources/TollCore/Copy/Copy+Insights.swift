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
      percent <= 0 ? "▼ \(-percent)% since the first week" : "▲ \(percent)% since the first week"
    }
    public static func weekLabel(_ n: Int) -> String { "Week \(n)" }
    public static let when = "When it stopped you"
    public static func mostAt(_ hour: String) -> String { "Most at \(hour)" }
    public static let empty = "Nothing yet. Your nights show here after the first one."
  }
}
