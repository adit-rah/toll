import Foundation

extension Copy {
  /// The block screen (spec §7), drawn by the system from these strings.
  public enum Shield {
    public static func title(until end: String) -> String { "Blocked until \(end)" }
    public static let title = "Blocked"
    public static let subtitle = "This app is blocked for the night."
    /// Every block's title is "Blocked until …"; the subtitle names the block (the audit).
    public static func blockOn(_ block: String) -> String { "This app is blocked during \(block)." }
    /// D32, after Opal: the easy way out is the first button.
    public static let neverMind = "Never mind"
    /// Opens the app at the pause sheet (D67): the block screen can't start a wait itself, and
    /// "Pause in Dusk" read as "Dusk is paused" (the audit).
    public static let unlock = "Open \(name) to pause"
    public static func pauses(_ left: Int, of max: Int) -> String {
      "\(left) of \(max) pauses left this week."
    }
    public static func noneLeft(back day: String) -> String {
      "No pauses left. They come back \(day)."
    }
  }
}
