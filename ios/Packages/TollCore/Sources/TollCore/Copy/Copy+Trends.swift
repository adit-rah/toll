import Foundation

extension Copy {
  /// Your sleep's measures (#87, #88): the person's nights against their own first nights, in plain
  /// numbers. A change is a fact about them, never a grade, a norm or praise; with too few nights,
  /// nothing is said. Dusk's own stand-ins say what they are.
  public enum Trends {
    public static let title = "Night by night"

    public static func name(_ kind: SleepTrends.Kind) -> String {
      switch kind {
      case .asleepBy: "Asleep by"
      case .timeAsleep: "Time asleep"
      case .steadiness, .phoneSteadiness: "How steady"
      case .reaches: "Reaching for your phone"
      case .phoneDown: "Phone down by"
      case .nightsLocked: "Nights locked"
      }
    }

    /// The value now: a clock time from minutes after the night's noon, a length, a spread, a
    /// count a night.
    static func value(_ kind: SleepTrends.Kind, _ value: Double, calendar: Calendar, anchor: Date)
      -> String
    {
      switch kind {
      case .asleepBy, .phoneDown:
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: anchor) ?? anchor
        // Rounded to five minutes, as people say a time (SleepEstimate's rounding).
        let minutes = (value / 5).rounded() * 5
        return time(noon.addingTimeInterval(minutes * 60), in: calendar)
      case .timeAsleep: return length(minutes: Int((value / 5).rounded() * 5))
      case .reaches: return perNight(value)
      case .steadiness, .phoneSteadiness: return spread(value)
      case .nightsLocked: return String(Int(value))
      }
    }

    /// "1.4", "2": one decimal under ten.
    static func perNight(_ value: Double) -> String {
      let tenths = (value * 10).rounded() / 10
      return tenths == tenths.rounded() ? String(Int(tenths)) : String(format: "%.1f", tenths)
    }

    static func spread(_ minutes: Double) -> String { "± \(Int(minutes.rounded())) min" }
    static func of(_ n: Int, _ total: Int) -> String { "\(n) of \(total)" }

    /// What the value is, and over how many nights.
    static func detail(_ kind: SleepTrends.Kind, nights n: Int) -> String {
      switch kind {
      case .asleepBy: "On average, last \(n) nights"
      case .timeAsleep: "A night on average, last \(n) nights"
      case .steadiness: "Around your usual time, last \(n) nights"
      case .reaches: "Times a night, last \(n) nights"
      case .phoneDown: "Your last reach for a locked app, on average, last \(n) nights"
      case .phoneSteadiness: "Around your usual last reach, last \(n) nights"
      case .nightsLocked: "The last \(n) nights"
      }
    }

    /// "25 min earlier than your first 7 nights", "About the same as your first 7 nights".
    static func change(_ kind: SleepTrends.Kind, by d: Double, way: SleepTrends.Way, first: Int)
      -> String
    {
      let than = "than your first \(first) nights"
      guard way != .steady else { return "About the same as your first \(first) nights" }
      let minutes = Int((abs(d) / 5).rounded() * 5)
      switch kind {
      case .asleepBy, .phoneDown:
        return "\(minutes) min \(d < 0 ? "earlier" : "later") \(than)"
      case .timeAsleep:
        return "\(shortLength(minutes)) \(d > 0 ? "more" : "less") \(than)"
      case .reaches:
        return "\(perNight(abs(d))) \(d < 0 ? "fewer" : "more") a night \(than)"
      case .nightsLocked:
        let n = Int(abs(d).rounded())
        return "\(n) \(d > 0 ? "more" : "fewer") \(than)"
      case .steadiness, .phoneSteadiness:
        return ""
      }
    }

    /// How steady, which has no plain "earlier": the first nights' spread, so the two can be read
    /// side by side.
    static func steadyChange(from first: Double, way: SleepTrends.Way, first nights: Int) -> String
    {
      way == .steady
        ? "About the same as your first \(nights) nights"
        : "From \(spread(first)) in your first \(nights) nights"
    }

    static func shortLength(_ minutes: Int) -> String {
      minutes < 60 ? "\(minutes) min" : Copy.length(minutes: minutes)
    }

    static func locked(_ n: Int, of total: Int) -> String {
      "Locked \(n) of the last \(total) nights"
    }

    static func pauses(_ n: Int, nights: Int) -> String {
      switch n {
      case 0: "No pauses in the last \(nights) nights"
      case 1: "1 pause in the last \(nights) nights"
      default: "\(n) pauses in the last \(nights) nights"
      }
    }

    /// One sentence for VoiceOver: "Asleep by 11:20 pm, on average, last 7 nights. 25 min earlier
    /// than your first 7 nights."
    static func spoken(_ kind: SleepTrends.Kind, value: String, detail: String, change: String?)
      -> String
    {
      let value = value.replacingOccurrences(of: "±", with: "within")
      let line = "\(name(kind)): \(value). \(detail)."
      return change.map { "\(line) \($0)." } ?? line
    }

    /// Under the measures, where they come from.
    public static let fromDusk =
      "From Dusk's own nights, not measured sleep. A watch adds real sleep times."
    public static let healthEmpty =
      "Health has no sleep for these nights. A watch adds real sleep times."
    /// Your sleep's quiet way to Health for people who didn't choose it.
    public static let addHealth = "Add your sleep from Apple Health"
    /// Before any measure has nights enough.
    public static let empty = "How your nights change shows here after a few nights."
  }
}
