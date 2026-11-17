import Foundation

extension Copy {
  /// The device-testing screen of spec §12 step 2. It goes when setup and Status replace it (steps 4
  /// and 5); the log stays, in Settings.
  public enum Trigger {
    public static let title = "Trigger"
    public static let state = "State"
    public static let blocked = "Blocked"
    public static let notBlocked = "Not blocked"
    public static func until(_ time: String) -> String { "Until \(time)" }
    public static let home = "Home"
    public static let away = "Away"
    public static let unknown = "Not known yet"
    public static let windowOnly = "Location off · the window alone decides"
    public static let inWindow = "Inside the window"
    public static let outsideWindow = "Outside the window"
    public static let entitled = "Entitled"
    public static let notEntitled = "Not entitled"
    public static let pending = "An edit waits for the block to end"

    public static let permissions = "Permissions"
    public static let screenTime = "Screen Time"
    public static let location = "Location"
    public static let allow = "Allow"
    public static let allowed = "Allowed"
    public static let notAsked = "Not asked"
    public static let denied = "Denied"
    public static let whileUsing = "While using · tap Allow again for Always"
    public static let always = "Always"
    public static let approximate = "Approximate · turn on Precise Location"

    public static let window = "Sleep window"
    public static let wake = "Wake time"
    public static let start = "Start"
    public static let save = "Save"

    public static let homeSection = "Home"
    public static let setHomeHere = "Set home here"
    public static let locating = "Finding you…"
    public static let noFix = "No accurate location yet. Try again outside."
    public static func radius(_ meters: Int) -> String { "\(meters) m around the point set" }
    public static let noHome = "No home set"

    public static let keepOpen = "Keep open"
    public static let choose = "Choose"
    public static func kept(apps: Int, sites: Int, categories: Int) -> String {
      var parts = ["\(apps) apps", "\(sites) sites"]
      if categories > 0 { parts.append("\(categories) categories (not kept open)") }
      return parts.joined(separator: middleDot)
    }

    public static let log = "Transition log"
    public static let reconcileNow = "Reconcile now"
    public static func line(_ transition: Transition, in calendar: Calendar = .current) -> String {
      let day = transition.at.formatted(
        Date.FormatStyle(
          date: .abbreviated, time: .omitted, calendar: calendar, timeZone: calendar.timeZone))
      let result = transition.blockOn ? "on" : "off"
      let home = transition.home.map { $0 ? "home" : "away" } ?? "home ?"
      let window = transition.inWindow ? "window" : "no window"
      let change = transition.changed ? "→ \(result)" : "= \(result)"
      return [
        "\(day) \(time(transition.at, in: calendar))", transition.cause.rawValue, change, home,
        window,
      ].joined(separator: middleDot)
    }
  }
}
