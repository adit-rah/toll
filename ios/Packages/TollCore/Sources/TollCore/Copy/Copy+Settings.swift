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
    /// A change made during the night waits for it to end (B-3), and the row says when.
    public static func onlyAtHomeFrom(_ on: Bool, _ time: String) -> String {
      "\(on ? onlyAtHomeOn : off) from \(time)"
    }
    /// The latest night the block ran (`PastNight.latest`), with its day.
    public static let lastNight = "Last night"
    public static func lastNightSpan(day: String, _ from: String, _ until: String) -> String {
      "\(day) \(from) – \(until)"
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
    public static let testingOnly = "Testing only · removed before launch"
    public static let keepIt = Purchase.keep
    public static let restore = Purchase.restore
    public static let restored = "Purchase restored."

    public static let appearance = "Appearance"
    public static let dark = "Dark"
    public static let light = "Light"
    public static let matchPhone = "Match iPhone"

    public static let help = "Help"
    public static let howItWorks = "How it works"
    /// Built from `TollConfig`, so the numbers can't drift from what the app does (#52).
    public static func howItWorksLines(
      _ config: TollConfig = .defaults, in calendar: Calendar = .current
    ) -> [String] {
      let day = weekdayName(config.unlocks.refillWeekday, in: calendar)
      return [
        "During your night, the apps you chose don't open. Everything else works.",
        "With home set and location on Always, your night starts once you're home. Otherwise it starts and ends at its set times, wherever you are.",
        aroundSleep(config, day: day),
        "A pause opens blocked apps for \(config.door.minutes) minutes, after \(wait(config.door.waitSeconds)). You get \(config.unlocks.max) a week, back every \(day) at noon.",
        "Other blocks work the same way, on their own hours.",
      ]
    }

    /// The buffers and their weekly rule (D76, #144), which runs with Dusk closed (#127).
    static func aroundSleep(_ config: TollConfig, day: String) -> String {
      let step =
        config.gap.step == config.after.step ? "\(config.gap.step) min" : "a step"
      return
        "Apps lock a while before you fall asleep and stay locked a while after you wake. Set to grow with you, each can change every \(day) at noon: \(step) longer after a week with few pauses in it, \(step) shorter after one with \(config.gap.hardPauses) or more."
    }

    static func wait(_ seconds: Int) -> String {
      guard seconds % 60 == 0 else { return "a \(seconds)-second wait" }
      return seconds == 60 ? "a one-minute wait" : "a \(seconds / 60)-minute wait"
    }

    /// A weekday's name in the phone's language, by `Calendar` numbering (1 is Sunday): 4 January
    /// 2026 was a Sunday.
    static func weekdayName(_ weekday: Int, in calendar: Calendar) -> String {
      let day = calendar.date(
        from: DateComponents(year: 2026, month: 1, day: 3 + weekday, hour: 12))
      return day.map { Copy.weekday($0, in: calendar) } ?? ""
    }
    public static let privacy = "Privacy"
    public static let privacyLine = "No servers. We never see your data"
    public static let contact = "Contact"
    public static let log = "Activity log"
    public static let logEmpty = "Nothing yet."
    /// Testing only, with the transition log: the night records as a file (#51).
    public static let shareNights = "Share night records"
    public static let version = "Version"
    public static func versionLine(_ number: String) -> String { "\(version) \(number)" }

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
