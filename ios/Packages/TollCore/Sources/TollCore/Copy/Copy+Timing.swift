import Foundation

extension Copy {
  /// Personal timing (D65, D66, #171): offered once after the first week, in plain words, with
  /// what it does, what it never does, and where it's turned off. Its claims go no further than
  /// the model's: it tries a start, compares, and learns.
  public enum Timing {
    /// Tonight's card, the one-time flow's.
    public static let cardTitle = "Learn what helps your sleep"
    public static func cardDetail(_ minutes: Int) -> String {
      "Some weeks, apps could lock up to \(minutes) min earlier or later."
    }
    public static let cardAction = "See how"

    /// Its sheet.
    public static let title = "Learn what helps your sleep"
    public static let line =
      "\(name) can try a slightly different start some weeks and compare how you slept, from Apple Health. It all stays on this phone."
    public static func moves(_ minutes: Int) -> String {
      "Some weeks, apps lock up to \(minutes) min earlier or later"
    }
    public static let movesDetail = "One start for the whole week, Monday to Sunday"
    public static let wake = "Your wake-up time never moves"
    public static let wakeDetail = "Apps open again at the same time"
    public static func limits(_ minutes: Int) -> String {
      "Never more than \(minutes) min before sleep"
    }
    public static let limitsDetail = "And never after you fall asleep"
    public static let off = "Turn it off any time"
    public static let offDetail = "In Settings › Sleep"
    public static let turnOn = "Turn on"
    public static let keep = "Keep my own time"

    /// Settings › Sleep's switch.
    public static let row = "Learn what helps your sleep"
    public static func rowDetail(_ minutes: Int) -> String {
      "Some weeks, up to \(minutes) min earlier or later"
    }
    public static let rowNeedsHealth = "Needs your sleep from Apple Health"
    public static func thisWeek(_ offset: Int) -> String {
      offset == 0 ? "This week: your own time" : "This week: \(moved(offset))"
    }

    /// Tonight, under the lock's time, in one line at the default size.
    public static func held(_ offset: Int) -> String {
      "\(moved(offset)) this week, to learn what helps"
    }
    public static func heldSpoken(_ offset: Int) -> String {
      "\(abs(offset)) minutes \(offset < 0 ? "earlier" : "later") this week, to learn what helps your sleep"
    }

    static func moved(_ offset: Int) -> String {
      "\(abs(offset)) min \(offset < 0 ? "earlier" : "later")"
    }
  }
}
