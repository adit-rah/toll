import Foundation

extension Copy {
  /// Blocks and the block editor (the design canvas; decisions D29).
  public enum Blocks {
    public static let title = "Blocks"
    public static let line =
      "A block is a list of apps, a place, and the hours they're blocked there."
    public static func summary(categories: Int, apps: Int, sites: Int = 0) -> String {
      let count = Setup.blockedCount(categories: categories, apps: apps, sites: sites)
      return count.isEmpty ? "No apps" : count
    }
    public static let new = "New block"
    public static let wholeCategory = "Whole category"
    public static let website = "Website"
    public static func limits(_ maxApps: Int) -> String {
      "Each block has its own apps. Unlocks are shared. Up to \(maxApps) apps across all blocks."
    }

    public static let editTitle = "Edit block"
    public static func kindName(_ kind: Block.Kind) -> String {
      switch kind {
      case .sleep: Setup.sleepName
      case .study: "Study"
      case .work: "Work"
      case .gym: "Gym"
      case .other: "Other"
      }
    }
    public static let name = "Name"
    public static let place = "Place"
    public static let anywhere = Setup.anywhere
    public static let hours = "Hours"
    public static let apps = "Apps to block"
    public static let chooseApps = Setup.chooseApps
    public static let explainer = "Inside these hours, at this place, these apps won't open."
    public static let save = "Save block"
    public static let delete = "Delete block"
    public static let deleteConfirm = "Delete this block?"
    public static let on = "On"
    public static let changesLater = "Changes apply when this block ends."

    public static let whereTitle = "Where?"
    public static let search = "Search for a place"
    public static let currentLocation = Setup.currentLocation
    public static let usePlace = "Use this place"
    public static let noPlace = "Anywhere: no place"
    public static let building = "Building"
    public static let street = "Block"
    public static let campus = "Campus"

    public static let from = "From"
    public static let until = "Until"
    public static let days = "Days"
    public static let done = Setup.done
    public static func daySpan(_ days: Set<Weekday>) -> String {
      if days == Weekday.all { return Home.everyDay }
      if days == Weekday.weekdays { return "Mon–Fri" }
      if days == [.saturday, .sunday] { return "Sat–Sun" }
      return days.sorted().map(Home.shortDay).joined(separator: " ")
    }
    public static func dayLetter(_ day: Weekday) -> String {
      ["M", "T", "W", "T", "F", "S", "S"][day.rawValue - 1]
    }

    public static func refused(_ error: CommandError, maxApps: Int, maxBlocks: Int) -> String {
      switch error {
      case .tooManyApps: "Up to \(maxApps) apps and sites across all blocks."
      case .tooManyBlocks: "Up to \(maxBlocks) blocks."
      case .tooManyWindows:
        "Too many different hours across blocks. Share hours with another block."
      case .tooManyPlaces: "Too many places."
      case .invalidSchedule: "Choose hours at least 15 minutes long, on at least one day."
      case .unknownPlace: "Choose the place again."
      case .sleepBlockCannotBeDeleted: "Sleep can be changed but not deleted."
      case .noSleepBlock: "There is already a Sleep block."
      case .door: ""
      }
    }
  }
}
