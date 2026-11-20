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
    public static let lastNight = "Last night"
    public static func blocked(_ from: String, _ until: String?) -> String {
      until.map { "Blocked \(from) – \($0)" } ?? "Blocked from \(from)"
    }
    public static let notYet = "Not yet"

    public static let yourWeek = "Your week"
    public static let freeNights = "Free nights"
    public static func nightsUsed(_ night: Int, of nights: Int) -> String {
      "\(night) of \(nights) used"
    }
    public static let purchased = "Purchased"
    public static func once(_ price: String) -> String { "\(price) once" }
    public static let app = "App"
    public static func blocksSummary(blocks: Int, items: Int, max: Int) -> String {
      "\(blocks == 1 ? "1 block" : "\(blocks) blocks")\(middleDot)\(items) of \(max) apps and sites"
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
    public static let howItWorks = "How blocking works"
    public static let howItWorksLines = [
      "A block is on when you're at its place, in its hours.",
      "Apps on its list don't open. Everything else works.",
      "Unlock in \(name) opens one app for 5 minutes after a short wait. You have 3; one comes back after 7 nights without using any.",
      "Without location set to Always, blocks run on their hours, wherever you are.",
    ]
    public static let privacy = "Privacy"
    public static let privacyLine = "No servers. We never see your data"
    public static let contact = "Contact"
    public static let log = "Transition log"
    public static let logEmpty = "Nothing yet."
    public static let version = "Version"

    public static func line(_ transition: Transition, in calendar: Calendar = .current) -> String {
      let day = transition.at.formatted(
        Date.FormatStyle(
          date: .abbreviated, time: .omitted, calendar: calendar, timeZone: calendar.timeZone))
      let result = transition.blockOn ? "on" : "off"
      let home = transition.home.map { $0 ? "home" : "away" } ?? "home ?"
      let window = transition.inWindow ? "window" : "no window"
      let change = transition.changed ? "→ \(result)" : "= \(result)"
      let door = transition.door.map { "door \($0.rawValue)" }
      let blocks = transition.active.map { "blocks \($0.map(\.raw).joined(separator: ","))" }
      return
        ([
          "\(day) \(time(transition.at, in: calendar))", transition.cause.rawValue, change, home,
          window,
        ] + [door, blocks].compactMap { $0 }).joined(separator: middleDot)
    }
  }
}
