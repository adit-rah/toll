import Foundation

extension Copy {
  /// The gap before bed (D76): apps lock a little before bed, and wake never moves. "Before bed",
  /// never "bedtime" (D74).
  public enum Gap {
    /// Under Tonight's "Apps lock at 10:15 pm".
    public static func beforeBed(_ minutes: Int) -> String { "\(minutes) min before bed" }
    /// The strip's snippet and Ready: where bed is.
    public static func bedAt(_ time: String) -> String { "Bed at \(time)" }
    /// The night's picture read out, after the night: "apps lock at 10:15 pm".
    public static func locksAt(_ time: String) -> String { "apps lock at \(time)" }

    /// Monday's card: this week's number, and last week's when it grew. An ease says only the new
    /// number (D65).
    public static func weekCard(_ minutes: Int) -> String {
      "This week, apps lock \(minutes) min before bed"
    }
    public static func upFrom(_ minutes: Int) -> String { "Up from \(minutes)" }
    public static func keep(_ minutes: Int) -> String { "Keep \(minutes)" }
    public static let okay = "OK"

    /// The one card for an install from before D76.
    public static func offerCard(_ minutes: Int) -> String {
      "Lock apps \(minutes) min before bed?"
    }
    public static func offerDetail(lock: String, wake: String) -> String {
      "Apps lock at \(lock). Your night still ends at \(wake)."
    }
    public static let turnOn = Home.turnOn

    /// Settings › Before bed.
    public static let row = "Before bed"
    public static let grows = "Grows with you"
    public static let fixed = "Fixed"
    public static func now(_ minutes: Int) -> String { "now \(minutes) min" }
    public static func next(_ minutes: Int) -> String { "next \(minutes)" }
    public static func fixedDetail(_ minutes: Int) -> String {
      minutes == 0 ? "None · apps lock at bed" : "\(fixed)\(middleDot)\(minutes) min"
    }
    /// "Grows with you · now 30 min · next 45".
    public static func growsDetail(_ minutes: Int, next: Int?) -> String {
      ([grows, now(minutes)] + [next.map(Self.next)].compactMap { $0 })
        .joined(separator: middleDot)
    }
    public static let fromTomorrow = "From tomorrow night"

    /// The sheet Settings opens.
    public static let sheetTitle = "Before bed"
    public static let sheetBody =
      "Apps lock a little before bed. Your night still ends when you get up."
    public static func growsOption(step: Int, cap: Int) -> String {
      "Up \(step) min after a week with few pauses, to \(cap). Down \(step) after a week with more."
    }
    public static let fixedOption = "The same every night"
    public static func minutesBefore(_ minutes: Int) -> String { "\(minutes) min before bed" }
    public static let tonightStays = "Tonight stays as it is. This applies from tomorrow night."
    public static let done = "Done"

    /// Ready: the gap a new night starts with.
    public static func readyRow(_ minutes: Int) -> String { beforeBed(minutes) }
    public static func readyDetail(cap: Int) -> String { "Grows with you, up to \(cap) min" }
  }
}
