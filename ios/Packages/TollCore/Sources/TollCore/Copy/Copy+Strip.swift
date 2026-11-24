import Foundation

extension Copy {
  /// Tonight's strip of the day and the snippet a tap on it opens (D75). The night is "Your night",
  /// never a block (D68); each state says when, in words anyone uses.
  public enum Strip {
    public static let yourNight = "Your night"
    public static let onNow = Home.onNow
    public static let paused = "Paused"
    public static let tonight = "Tonight"
    public static let laterToday = "Later today"
    public static let tomorrow = "Tomorrow"
    public static let ended = "Ended"
    public static let off = Home.off
    public static let waiting = Blocks.waiting
    public static let whenHome = "Apps lock when you're home"
    public static let whenThere = "Apps lock when you're there"
    public static let edit = "Edit"
    /// The strip's VoiceOver action and the snippet link's label: "Edit Your night", "Edit Study".
    public static func edit(_ title: String) -> String { "Edit \(title)" }
    /// What a tap on the strip does, for VoiceOver.
    public static let hint = "Shows its hours, apps and place"
    public static func now(_ time: String) -> String { "Now, \(time)" }
  }
}
