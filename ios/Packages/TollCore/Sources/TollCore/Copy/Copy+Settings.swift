import Foundation

extension Copy {
  /// Settings (the design canvas).
  public enum Settings {
    public static let title = "Settings"
    public static let working = "Is everything working?"
    public static let screenTime = "Screen Time"
    public static let location = "Location"
    public static let on = "On"
    public static let off = "Off"
    public static let always = "Always"
    public static let whileUsing = "While Using"
    public static let approximate = "Approximate"
    /// The same entry as Tonight's home card (D68), kept after the card is dismissed.
    public static let onlyAtHome = "Only when I'm home"
    public static let onlyAtHomeOn = "On"
    public static let onlyAtHomeOff = "Off · runs wherever you are"
    /// The latest stretch any block was on (`LastNight`), which isn't always a night.
    public static let lastNight = "Last blocked"
    public static func blocked(_ from: String, _ until: String?) -> String {
      until.map { "\(from) – \($0)" } ?? "Since \(from)"
    }
    public static let notYet = "Not yet"

    public static let yourWeek = "Your week"
    public static let freeNights = "Free nights"
    /// The pill's words: tonight's night hasn't ended, so it isn't "used" yet (spec §3, #48).
    public static func night(_ night: Int, of nights: Int) -> String {
      "Night \(night) of \(nights)"
    }
    public static let purchased = "Purchased"
    public static let purchasedDetail = "Every night, for good"
    public static func once(_ price: String) -> String { "\(price) once" }
    public static let app = "App"
    /// No count of blocks: the night isn't a block to people (D68), and the limit is what matters.
    public static func blocksSummary(items: Int, max: Int) -> String {
      "\(items) of \(max) apps and sites"
    }
    public static let testingOnly = "Testing only · removed before launch"
    public static let keepIt = Purchase.keep
    public static let restore = Purchase.restore
    public static let restored = "Purchase restored."

    public static let blocks = Blocks.title
    public static let appearance = "Appearance"
    public static let dark = "Dark"
    public static let light = "Light"
    public static let matchPhone = "Match iPhone"

    public static let help = "Help"
    public static let howItWorks = "How it works"
    public static let howItWorksLines = [
      "During your night, the apps you chose don't open. Everything else works.",
      "With home set and location on Always, your night starts once you're home. Otherwise it starts and ends at its set times, wherever you are.",
      "Pause opens every app for 10 minutes after a one-minute wait. You get 3 a week, back every Monday at noon.",
      "Other blocks work the same way, on their own hours.",
    ]
    public static let privacy = "Privacy"
    public static let privacyLine = "No servers. We never see your data"
    public static let contact = "Contact"
    public static let log = "Activity log"
    public static let logEmpty = "Nothing yet."
    /// Testing only, with the transition log: the night records as a file (#51).
    public static let shareNights = "Share night records"
    public static let version = "Version"

    public static func line(_ transition: Transition, in calendar: Calendar = .current) -> String {
      let day = transition.at.formatted(
        Date.FormatStyle(
          date: .abbreviated, time: .omitted, calendar: calendar, timeZone: calendar.timeZone))
      let result = transition.blockOn ? "on" : "off"
      let home = transition.home.map { $0 ? "home" : "away" } ?? "home ?"
      let window = transition.inWindow ? "window" : "no window"
      let change = transition.changed ? "→ \(result)" : "= \(result)"
      let door = transition.door.map { "pause \($0.rawValue)" }
      let blocks = transition.active.map { "blocks \($0.map(\.raw).joined(separator: ","))" }
      let access = transition.screenTime == false ? "Screen Time off" : nil
      return
        ([
          "\(day) \(time(transition.at, in: calendar))", transition.cause.rawValue, change, home,
          window,
        ] + [door, blocks, access].compactMap { $0 }).joined(separator: middleDot)
    }
  }
}
