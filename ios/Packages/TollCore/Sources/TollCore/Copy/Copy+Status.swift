import Foundation

extension Copy {
  /// The block screen (spec §7), drawn by the system from these strings.
  public enum Shield {
    public static func title(until end: String) -> String { "Blocked until \(end)" }
    public static let title = "Blocked"
    public static let subtitle = "This app is blocked for the night."
    public static func blockTitle(_ block: String, until end: String) -> String {
      "\(block) · until \(end)"
    }
    public static func blockOn(_ block: String) -> String { "This app is blocked during \(block)." }
    /// D32, after Opal: the easy way out is the first button.
    public static let neverMind = "Never mind"
    /// Opens the app at the pause sheet (D67): the block screen can't start a wait itself.
    public static let unlock = "Pause in \(name)"
    public static func pauses(_ left: Int, of max: Int) -> String {
      "\(left) of \(max) pauses left this week."
    }
  }
}
