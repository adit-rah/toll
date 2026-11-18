import Foundation

extension Copy {
  public enum Settings {
    public static let title = "Settings"
    public static let window = "Sleep window"
    public static let home = "Home"
    public static let blocked = "Blocked apps"
    /// B-3, under the first three rows.
    public static let changesLater = "Changes apply after tonight's block ends."
    public static let restore = "Restore purchase"
    public static let restored = "Purchase restored."
    public static let privacy = "Privacy policy"
    public static let support = "Support"
    public static let log = "Transition log"
    public static let version = "Version"
    public static let save = "Save"
    public static let wake = "Wake time"
    public static let start = "Nights start at"
    public static let homeSet = "Home is set."
    public static let homeNotSet = "No home set. The block runs every night in your sleep window."
    public static let moveHome = "Move home here"
    public static let finding = Setup.finding
    public static let noFix = Setup.noFix
    public static func blockedCount(apps: Int, sites: Int, categories: Int) -> String {
      var parts = [apps == 1 ? "1 app" : "\(apps) apps"]
      if sites > 0 { parts.append(sites == 1 ? "1 site" : "\(sites) sites") }
      if categories > 0 {
        parts.append(categories == 1 ? "1 category" : "\(categories) categories")
      }
      return parts.joined(separator: middleDot)
    }
    public static let notEmpty = "At least one app stays on the list."
    public static let logEmpty = "Nothing yet."

    public static func line(_ transition: Transition, in calendar: Calendar = .current) -> String {
      let day = transition.at.formatted(
        Date.FormatStyle(
          date: .abbreviated, time: .omitted, calendar: calendar, timeZone: calendar.timeZone))
      let result = transition.blockOn ? "on" : "off"
      let home = transition.home.map { $0 ? "home" : "away" } ?? "home ?"
      let window = transition.inWindow ? "window" : "no window"
      let change = transition.changed ? "→ \(result)" : "= \(result)"
      let door = transition.door.map { "door \($0.rawValue)" }
      return
        ([
          "\(day) \(time(transition.at, in: calendar))", transition.cause.rawValue, change, home,
          window,
        ] + [door].compactMap { $0 }).joined(separator: middleDot)
    }
  }
}
