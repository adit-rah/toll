import Foundation

extension Copy {
  /// The one notification before each night (D68, #104), its card on Tonight and its Settings row.
  /// Plain words (D65): the hours are "your night", never a window or a bedtime.
  public enum HeadsUp {
    /// Before the lock, which starts the gap before bed (D76).
    public static func title(minutes: Int) -> String { "Apps lock in \(minutes) min" }
    /// The lock to wake, as moon start – end sun puts it.
    public static func body(start: String, end: String) -> String { "\(start) – \(end)" }

    /// Tonight's card, from the morning after the first night.
    public static let card = "A heads-up before your night?"
    /// Under the card's title, the time it would arrive first: "9:55 pm · 20 min before apps lock".
    public static func cardDetail(time: String?, minutes: Int) -> String {
      let before = "\(minutes) min before apps lock"
      return time.map { "\($0)\(middleDot)\(before)" } ?? before
    }
    public static let turnOn = Home.turnOn
    public static let notNow = Home.notNow
    /// Once, after "Turn on" (#160), over the same detail as the card: when the first one comes.
    public static let isOn = "Heads-up on"
    /// After "Turn on", when iOS's prompt was refused: only iOS Settings can allow it now.
    public static let refused = "Notifications are off for Dusk"
    public static let refusedDetail = "Allow them in iOS Settings to get the heads-up."
    public static let ok = Morning.ok

    public static let row = "Heads-up"
    public static func rowDetail(minutes: Int) -> String { "\(minutes) min before apps lock" }
    /// Denied in iOS Settings: only iOS can turn it back on.
    public static let rowDenied = "Off in iOS Settings"
    public static let openSettings = Setup.openSettings
  }
}
