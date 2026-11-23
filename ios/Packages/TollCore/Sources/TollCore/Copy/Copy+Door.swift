import Foundation

extension Copy {
  /// The pause (D67): plain words, no Dusk-only terms (D65). The code keeps the spec's `Door`.
  public enum Door {
    /// What the dots say, spoken and beside them.
    public static func pausesLeft(_ left: Int, of max: Int) -> String {
      "\(left) of \(max) pauses left this week"
    }
    public static func pausesOf(_ left: Int, _ max: Int) -> String {
      "\(left) of \(max) left this week"
    }
    public static func noneOf(_ max: Int) -> String { "0 of \(max)" }
    /// The day the week's pauses come back: "Monday", or "today" on the morning of it.
    public static func refillDay(_ refill: Date, now: Date, in calendar: Calendar = .current)
      -> String
    {
      calendar.isDate(refill, inSameDayAs: now) ? "today" : weekday(refill, in: calendar)
    }
    public static func back(_ day: String) -> String { "back \(day)" }
    public static func noneLeftBack(_ day: String) -> String { "No pauses left · back \(day)" }
    /// Under This week while any is spent.
    public static func comeBack(_ day: String) -> String { "Pauses come back \(day)." }

    // Choosing
    public static func question(minutes: Int) -> String { "Pause blocking for \(minutes) minutes?" }
    public static func pauseFor(minutes: Int) -> String { "Pause for \(minutes) min" }
    public static let notNow = "Not now"
    public static func waitFirst(seconds: Int) -> String {
      "You wait \(seconds) seconds first. Cancelling costs nothing."
    }

    // Waiting
    public static func onceWaitEnds(minutes: Int) -> String {
      "Every app opens for \(minutes) minutes when the wait ends."
    }
    public static let leaveFreely = "You can leave this screen. The wait keeps going."
    public static func opensInSpoken(minutes: Int, seconds: Int) -> String {
      switch (minutes, seconds) {
      case (0, let s): "Opens in \(s) seconds."
      case (let m, 0): m == 1 ? "Opens in 1 minute." : "Opens in \(m) minutes."
      case (let m, let s): "Opens in \(m) minute\(m == 1 ? "" : "s") \(s) seconds."
      }
    }
    public static let cancel = "Cancel"
    public static let cancelFree = "Cancelling costs nothing."

    // Open
    public static let isOpen = "Paused"
    public static func locksAt(_ time: String) -> String { "Blocking again at \(time)" }
    public static let everyAppOpens = "Every app opens until then."
    public static let leftWord = "left"
    public static func leftSpoken(minutes: Int, seconds: Int) -> String {
      switch (minutes, seconds) {
      case (0, let s): "\(s) seconds left"
      case (let m, 0): m == 1 ? "1 minute left" : "\(m) minutes left"
      case (let m, let s): "\(m) minute\(m == 1 ? "" : "s") \(s) seconds left"
      }
    }
    /// D-4: said here and nowhere else.
    public static func regretFor(_ clock: String) -> String {
      "Lock again in the next \(clock) and you keep the pause."
    }
    public static let lockAgain = "Lock again"

    // None left
    public static let noneTitle = "No pauses left"
    public static func weekly(_ max: Int, refill: Date, in calendar: Calendar = .current) -> String
    {
      "You get \(max) a week. They come back when \(weekday(refill, in: calendar)) night starts."
    }
    public static let othersWork = "Everything you didn't block still works."
    public static let ok = "OK"
  }

  /// The day's name in the phone's language ("Monday").
  public static func weekday(_ date: Date, in calendar: Calendar = .current) -> String {
    let locale = calendar.locale.flatMap { $0.identifier.isEmpty ? nil : $0 } ?? .current
    let formatter = DateFormatter()
    formatter.locale = locale
    formatter.calendar = calendar
    formatter.timeZone = calendar.timeZone
    formatter.setLocalizedDateFormatFromTemplate("EEEE")
    return formatter.string(from: date)
  }
}
