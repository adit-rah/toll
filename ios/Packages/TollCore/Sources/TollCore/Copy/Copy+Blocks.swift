import Foundation

extension Copy {
  /// Blocks and the block editor (the design canvas; decisions D29).
  public enum Blocks {
    public static let title = "Blocks"
    public static let line =
      "Each block is a list of apps, the hours they're blocked, and an optional place."
    public static func summary(categories: Int, apps: Int, sites: Int = 0) -> String {
      let count = Setup.blockedCount(categories: categories, apps: apps, sites: sites)
      return count.isEmpty ? "No apps" : count
    }
    public static let new = "New block"
    public static let wholeCategory = "Whole category"
    public static let website = "Website"
    public static let appsAndSites = "Apps and sites"
    public static let timeWindows = "Time windows"
    public static func used(_ used: Int, of max: Int) -> String { "\(used) of \(max)" }
    public static let unlocksShared = "Unlocks are shared by all blocks."
    public static func blocksFull(_ max: Int) -> String { "Up to \(max) blocks." }
    public static func windowsFull(_ max: Int) -> String {
      "Up to \(max) time windows across all blocks."
    }
    public static func windowsUsed(_ used: Int, of max: Int) -> String {
      "\(used) of \(max) time windows used across all blocks. Blocks with the same hours share one."
    }
    public static func onNowUntil(_ time: String) -> String { "until \(time)" }
    public static func appCount(_ n: Int) -> String { n == 1 ? "1 app" : "\(n) apps" }
    public static func thisBlock(_ n: Int) -> String { "This block: \(n) apps and sites" }
    public static func allBlocks(_ used: Int, of max: Int) -> String {
      "All blocks: \(used) of \(max)"
    }
    public static func overLimit(_ max: Int, remove: Int) -> String {
      "Up to \(max) apps and sites across all blocks. Remove \(remove) here or from another block."
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
    public static let explainer = "During these hours, at this place, these apps won't open."
    public static let save = "Save block"
    public static let saveEdit = "Save"
    public static func saveAfter(_ time: String) -> String { "Save for after \(time)" }
    /// A held delete or edit, on the block's row (B-3, #49).
    public static func deletedAt(_ time: String) -> String { "Deleted at \(time)" }
    public static func changesAt(_ time: String) -> String { "Changes apply at \(time)" }
    public static func deleteHeld(_ block: String, until time: String) -> String {
      "\(block) is on until \(time). It's deleted then; until then its apps stay blocked."
    }
    public static func deleteAt(_ time: String) -> String { "Delete at \(time)" }
    /// D37: without Always and Precise every block runs on its hours wherever the user is (#49).
    public static func placeIgnored(_ block: String, span: String) -> String {
      "Location is set to While Using, so \(block) runs \(span) wherever you are."
    }
    public static func activeNote(_ block: String, until time: String) -> String {
      "\(block) is on until \(time). Changes apply when this block ends."
    }
    public static let sleepStays = "Sleep can be changed but not deleted."
    public static let delete = "Delete block"
    public static func deleteTitle(_ block: String) -> String { "Delete \(block)?" }
    public static func deleteLine(_ items: String, place: String?) -> String {
      "Its \(items) stop being blocked\(place.map { " at \($0)" } ?? ""). Your other blocks stay."
    }
    public static let cancel = "Cancel"
    public static let on = "On"
    public static let changesLater = "Changes apply when this block ends."

    public static let whereTitle = "Where?"
    public static let search = "Search for a place"
    public static let currentLocation = Setup.currentLocation
    public static let usePlace = "Use this place"
    public static let useAnywhere = "Use anywhere"
    public static let anywhereNote =
      "With no place, this block starts and ends on its hours alone. Location isn't used."
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
