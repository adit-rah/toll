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
    /// A settled week (D66, #182): the start is the one the insight supports, and the line points
    /// to it by the name of its place on Your sleep. No minutes here, so it never reads as a promise
    /// for tonight.
    public static func heldFound(_ offset: Int) -> String {
      "\(moved(offset)) this week, from what \(name) found"
    }
    public static func heldFoundSpoken(_ offset: Int) -> String {
      "\(abs(offset)) minutes \(offset < 0 ? "earlier" : "later") this week, from what \(name) found. It's on \(Tabs.sleep)."
    }

    /// Your sleep's insight (#189): the one sentence in the app that may say "because", since only
    /// the start was randomized. Sooner or later, the range, and the nights it rests on.
    public static let foundTitle = "What \(name) found"
    public static func foundValue(_ minutes: Int, sooner: Bool) -> String {
      "Asleep \(minutes) min \(sooner ? "sooner" : "later")"
    }
    public static func foundLine(sooner: Bool, earlier: Int) -> String {
      "You fell asleep \(sooner ? "sooner" : "later") because apps locked \(earlier) min earlier."
    }
    public static func foundDetail(_ low: Int, _ high: Int, nights: Int) -> String {
      let range = low == high ? "\(low)" : "\(low) to \(high)"
      return "Likely \(range) min, from \(nights) nights"
    }
    public static func foundSpoken(
      _ minutes: Int, sooner: Bool, earlier: Int, low: Int, high: Int, nights: Int
    ) -> String {
      let way = sooner ? "sooner" : "later"
      let range = low == high ? "\(low)" : "\(low) to \(high)"
      return
        "Asleep \(minutes) minutes \(way). You fell asleep \(way) because apps locked \(earlier) minutes earlier. Likely \(range) minutes, from \(nights) nights."
    }
    /// With personal timing on and nothing found yet. It may find nothing, so it promises nothing.
    public static func learning(nights: Int?) -> String {
      let so =
        switch nights ?? 0 {
        case 0: ""
        case 1: ", from 1 night so far"
        case let n: ", from \(n) nights so far"
        }
      return "\(name) is still learning what helps your sleep\(so). Anything it finds shows here."
    }

    static func moved(_ offset: Int) -> String {
      "\(abs(offset)) min \(offset < 0 ? "earlier" : "later")"
    }
  }
}
