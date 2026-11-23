import Foundation

extension Copy {
  /// The one notification before each night (D68, #104), its card on Tonight and its Settings row.
  /// Plain words (D65): the hours are "your night", never a window or a bedtime.
  public enum HeadsUp {
    public static func title(minutes: Int) -> String { "Night starts in \(minutes) min" }
    /// The night as moon start – end sun puts it.
    public static func body(start: String, end: String) -> String { "\(start) – \(end)" }

    /// Tonight's card, from the morning after the first night.
    public static let card = "A heads-up before your night?"
    /// Under the card's title, the time it would arrive first: "10:10 pm · 20 min before your night".
    public static func cardDetail(time: String?, minutes: Int) -> String {
      let before = "\(minutes) min before your night"
      return time.map { "\($0)\(middleDot)\(before)" } ?? before
    }
    public static let turnOn = Home.turnOn
    public static let notNow = Home.notNow

    public static let row = "Heads-up"
    public static func rowDetail(minutes: Int) -> String { "\(minutes) min before your night" }
    /// Denied in iOS Settings: only iOS can turn it back on.
    public static let rowDenied = "Off in iOS Settings"
    public static let openSettings = Setup.openSettings
  }
}
