import Foundation

extension Copy {
  /// Dusk fitted to the person's sleep (#144): onboarding's steps from Health or a question, the
  /// time around sleep, the one-time flow for people already using Dusk, and Settings › Sleep.
  /// Sleep is when they fall asleep, never "bed" (D74 bans "bedtime").
  public enum Fit {
    /// Welcome, under the free nights: the whole purchase, quieter (#144).
    public static func start(nights: Int) -> String { "Start my \(nights) free nights" }
    public static func buyNow(_ price: String) -> String { "Buy it now\(middleDot)\(price)" }

    public static let title = "Fit \(name) to your sleep"
    public static let line =
      "\(name) reads your past sleep from Apple Health to suggest your hours. It never leaves this phone."
    public static let useHealth = "Use Apple Health"
    public static let setMyself = "Set my hours myself"
    public static let healthWhy = "Sleep only. Nothing is written to Health."

    /// Your sleep: found in Health, or asked.
    public static func found(asleep: String, wake: String) -> String {
      "You usually fall asleep around \(asleep) and wake around \(wake)"
    }
    public static let ask = "When do you usually fall asleep and wake up?"
    public static func foundNote(_ nights: Int) -> String {
      "From your last \(nights) nights in Apple Health. Change either time if it's off."
    }
    public static let askNote = "Your best guess is fine. You can change it later in Settings."
    public static let fallAsleep = "Fall asleep"
    public static let wakeUp = "Wake up"
    public static let weekendsFound = "Fri and Sat nights are later, so they're set apart."
    /// The sleep drawn as moon asleep – wake sun, read out in one line.
    public static func sleepLabel(asleep: String, wake: String) -> String {
      "Asleep \(asleep) to \(wake)"
    }

    /// The time around sleep.
    public static let aroundTitle = "The time around your sleep"
    public static let aroundLine =
      "Apps lock a while before you fall asleep, and stay locked a while after you wake."
    public static let before = "Before sleep"
    public static let after = "After waking"
    public static let suggestedHealth = "Suggested from your sleep in Apple Health"
    public static let suggested = "Suggested to start"
    /// A buffer's row: tonight's minutes and what it grows to.
    public static func grows(_ minutes: Int, to target: Int) -> String {
      minutes >= target
        ? "\(minutes) min every night" : "\(minutes) min tonight, growing to \(target)"
    }
    public static let tonight = "Tonight"
    public static let growsTo = "Grows to"
    public static func minutes(_ minutes: Int) -> String { "\(minutes) min" }
    public static let growsNote =
      "Each grows a step after a week with few pauses, and eases back after a week with more."
    /// The drawing's ends: when apps lock, and when they open again.
    public static func lockAt(_ time: String) -> String { "Lock \(time)" }
    public static func openAt(_ time: String) -> String { "Open \(time)" }
    public static func pictureLabel(lock: String, asleep: String, wake: String, open: String)
      -> String
    {
      "Apps lock at \(lock), asleep \(asleep) to \(wake), apps open at \(open)"
    }

    /// Ready and Tonight: the buffer after waking, beside "15 min before sleep".
    public static func afterWaking(_ minutes: Int) -> String { "\(minutes) min after waking" }
    public static func readyDetail(target: Int) -> String { "Grows with you, up to \(target) min" }

    /// The one-time flow for people already using Dusk (#144), as Tonight's card and its sheet.
    public static let cardTitle = "Fit \(name) to your sleep"
    public static let cardDetail =
      "Set when you sleep, and a while before and after it with apps locked."
    public static let cardAction = "Start"
    public static let save = "Save"
    public static let cancel = "Cancel"

    /// Settings › Sleep: sleep and both buffers in one place.
    public static let row = "Sleep"
    /// "11:20 pm – 7:10 am · 15 min before · 10 min after".
    public static func rowDetail(sleep: String, before: Int, after: Int) -> String {
      [sleep, "\(before) min before", "\(after) min after"].joined(separator: middleDot)
    }
    public static let sheetTitle = "Sleep"
    public static let sheetBody =
      "When you usually sleep, and how long apps stay locked around it."
    public static let weekends = "Fri and Sat nights"
  }
}
