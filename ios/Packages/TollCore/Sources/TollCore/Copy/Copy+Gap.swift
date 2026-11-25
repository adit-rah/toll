import Foundation

extension Copy {
  /// The buffers around sleep (D76, #144): apps lock a little before sleep and stay locked a little
  /// after waking. "Before sleep", never "bedtime" (D74).
  public enum Gap {
    /// Under Tonight's "Apps lock at 10:15 pm".
    public static func beforeBed(_ minutes: Int) -> String { "\(minutes) min before sleep" }
    /// The strip's snippet: sleep inside the lock.
    public static func sleepSpan(_ asleep: String, _ wake: String) -> String {
      "Sleep \(asleep) – \(wake)"
    }

    /// Monday's card: this week's number, and last week's when it grew. An ease says only the new
    /// number (D65).
    public static func weekCard(_ minutes: Int) -> String {
      "This week, apps lock \(minutes) min before sleep"
    }
    public static func afterWeekCard(_ minutes: Int) -> String {
      "This week, apps stay locked \(minutes) min after you wake"
    }
    /// Both sides changed the same Monday: one line names both, so neither goes unsaid.
    public static func bothWeekCard(before: Int, after: Int) -> String {
      "This week, apps lock \(before) min before sleep and stay locked \(after) min after you wake"
    }
    public static func upFrom(_ minutes: Int) -> String { "Up from \(minutes)" }
    public static func upFromBoth(_ before: Int, _ after: Int) -> String {
      "Up from \(before) and \(after)"
    }
    public static func keep(_ minutes: Int) -> String { "Keep \(minutes)" }
    public static let keepBoth = "Keep last week's"
    public static let okay = "OK"

    /// The one card for an install from before D76.
    public static func offerCard(_ minutes: Int) -> String {
      "Lock apps \(minutes) min before sleep?"
    }
    public static func offerDetail(lock: String, wake: String) -> String {
      "Apps lock at \(lock). Your night still ends at \(wake)."
    }
    public static let turnOn = Home.turnOn

    /// Settings › Sleep, each side.
    public static let grows = "Grows with you"
    public static let fixed = "Fixed"
    public static func now(_ minutes: Int) -> String { "now \(minutes) min" }
    public static func next(_ minutes: Int) -> String { "next \(minutes)" }
    public static func fixedDetail(_ minutes: Int) -> String {
      minutes == 0 ? "None" : "\(fixed)\(middleDot)\(minutes) min"
    }
    /// "Grows with you · now 30 min · next 45".
    public static func growsDetail(_ minutes: Int, next: Int?) -> String {
      ([grows, now(minutes)] + [next.map(Self.next)].compactMap { $0 })
        .joined(separator: middleDot)
    }
    public static let fromTomorrow = "From tomorrow night"

    public static let fixedOption = "The same every night"
    public static let tonightStays = "Tonight stays as it is. This applies from tomorrow night."
  }
}
