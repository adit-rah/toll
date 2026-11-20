import Foundation

extension Copy {
  /// The block screen (spec §7), drawn by the system from these strings.
  public enum Shield {
    public static func title(until end: String) -> String { "Blocked until \(end)" }
    public static let title = "Blocked"
    public static let subtitle = "It's your sleep time."
    public static func blockTitle(_ block: String, until end: String) -> String {
      "\(block) · until \(end)"
    }
    public static func blockOn(_ block: String) -> String { "This app is blocked during \(block)." }
    /// D32, after Opal: the easy way out is the first button.
    public static let neverMind = "Never mind"
    public static let unlock = "Unlock in \(name)"
    public static func unlocks(_ left: Int, of max: Int) -> String {
      "\(left) of \(max) unlocks left."
    }
  }
}
