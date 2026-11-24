import Foundation

extension Copy {
  /// The morning card on Tonight (D65, #103). Facts about the person's own night, never praise; the
  /// hours are the night (D68), and the block isn't called "Sleep".
  public enum Morning {
    public static let lastNight = "Last night"
    public static func putDown(_ n: Int) -> String {
      n == 1 ? "You put it down once" : "You put it down \(n) times"
    }
    public static let away = "Away from home"
    public static let noScreenTime = "Screen Time was off"

    /// "Blocked from 10:30 pm to 7:00 am, open from 12:40 am to 12:50 am".
    public static func spokenRan(from: String, to: String, gaps: [(String, String)]) -> String {
      (["Blocked from \(from) to \(to)"] + gaps.map { "open from \($0.0) to \($0.1)" })
        .joined(separator: ", ")
    }
    public static func spokenAway(from: String, to: String) -> String {
      "Away from home from \(from) to \(to), nothing blocked"
    }
    public static func spokenNoScreenTime(from: String, to: String) -> String {
      "Screen Time was off from \(from) to \(to), nothing blocked"
    }
  }

  /// Your sleep (D63, D65, #103): one number per card, compared only with the person's own past.
  public enum YourSleep {
    /// "23 nights locked" (founder, 24 Nov): the count says what it counts.
    public static func nights(_ n: Int) -> String {
      n == 1 ? "1 night locked" : "\(n) nights locked"
    }
    public static let newWeek = "A new week"
    public static func lastWeek(_ n: Int) -> String {
      n == 1 ? "1 night last week" : "\(n) nights last week"
    }
    public static func best(_ n: Int) -> String { "\(n) nights this week" }
    public static let bestDetail = "Your most in a week"
  }
}
