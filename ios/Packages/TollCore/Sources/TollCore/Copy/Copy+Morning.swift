import Foundation

extension Copy {
  /// Last night's card on Tonight (D65, #103), to review. Facts about the person's own night, never
  /// praise; each part says what it is to someone reading it for the first time. The hours are the
  /// night (D68), and the block isn't called "Sleep".
  public enum Morning {
    /// The eyebrow, and last night's place on the strip.
    public static let lastNight = "Last night"
    /// Over the bar: what it shows.
    public static func locked(from: String, to: String) -> String {
      "Apps locked from \(from) to \(to)"
    }
    /// Under the bar, where it breaks: a pause, or a time away.
    public static func open(_ breaks: [(String, String)]) -> String? {
      guard let first = breaks.first else { return nil }
      return breaks.count == 1
        ? "Apps open from \(first.0) to \(first.1)" : "Apps open \(breaks.count) times in the night"
    }
    /// The "Never mind" taps on the block screen: each time a locked app was opened and left
    /// (the founder's "You chose sleep", 24 Nov 2026).
    public static func putDown(_ n: Int) -> String {
      n == 1
        ? "You chose sleep over a locked app once"
        : "You chose sleep over a locked app \(n) times"
    }
    public static let away = "Away from home, so nothing locked"
    public static let noScreenTime = "Screen Time was off, so nothing locked"
    /// Over the dots: the last seven nights, or the first seven from setup with some still to come.
    public static let lastSeven = "Last 7 nights"
    public static let firstSeven = "Your first 7 nights"
    /// Puts the card away for this morning; the strip still opens it.
    public static let ok = "OK"

    /// "Apps locked from 10:30 pm to 7:00 am, open from 12:40 am to 12:50 am".
    public static func spokenRan(from: String, to: String, gaps: [(String, String)]) -> String {
      ([locked(from: from, to: to)] + gaps.map { "open from \($0.0) to \($0.1)" })
        .joined(separator: ", ")
    }
    public static func spokenAway(from: String, to: String) -> String {
      "Away from home from \(from) to \(to), so nothing locked"
    }
    public static func spokenNoScreenTime(from: String, to: String) -> String {
      "Screen Time was off from \(from) to \(to), so nothing locked"
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
