import Foundation

extension Copy {
  public enum Status {
    public static func blocked(until end: String) -> String { "Blocked until \(end)" }
    public static func starts(at start: String, windowOnly: Bool) -> String {
      windowOnly ? "Starts at \(start)" : "Starts at \(start), if you're home"
    }
    public static let away = "You're away. Nothing is blocked."
    public static let noWindow = "No sleep window set"
    public static let settings = "Settings"
  }

  /// The block screen (spec §7), drawn by the system from these strings.
  public enum Shield {
    public static func title(until end: String) -> String { "Blocked until \(end)." }
    public static let title = "Blocked."
    public static let subtitle = "You're home and it's your sleep time."
    public static let subtitleWindowOnly = "It's your sleep time."
    public static func blockTitle(_ block: String, until end: String) -> String {
      "\(block) · until \(end)"
    }
    public static func atPlace(_ place: String) -> String { "You're at \(place)." }
    public static func blockOn(_ block: String) -> String { "\(block) is on." }
    /// D32, after Opal: the easy way out is the first button.
    public static let neverMind = "Never mind"
    public static let unlock = "Unlock in \(name)"
  }
}
