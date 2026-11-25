import Foundation

extension Copy {
  /// Blocks and the block editor (the design canvas; decisions D29).
  public enum Blocks {
    public static let title = "Blocks"
    public static func summary(categories: Int, apps: Int, sites: Int = 0) -> String {
      let count = Setup.blockedCount(categories: categories, apps: apps, sites: sites)
      return count.isEmpty ? "No apps" : count
    }
    public static let new = "New block"
    public static let wholeCategory = "Whole category"
    public static let website = "Website"
    public static let appsAndSites = "Apps and sites"
    /// The schedules iOS lets the app keep (D40), in plain words: blocks with the same hours share one.
    public static let timeWindows = "Sets of hours"
    public static func used(_ used: Int, of max: Int) -> String { "\(used) of \(max)" }
    /// One sentence for the pause everywhere it's explained (the audit).
    public static let unlocksShared = "A pause opens blocked apps for 10 minutes."
    public static func blocksFull(_ max: Int) -> String { "Up to \(max) blocks." }
    public static func windowsFull(_ max: Int) -> String {
      "Up to \(max) sets of hours across all blocks."
    }
    public static func onNowUntil(_ time: String) -> String { "until \(time)" }
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
      case .sleep: night
      case .study: "Study"
      case .work: "Work"
      case .gym: "Gym"
      case .other: "Other"
      }
    }
    public static let name = "Name"
    /// The night's block is the user's nights, never a block called "Sleep" (D68).
    public static let night = "Night"
    public static let nightTitle = Setup.yourNights
    /// New block, before a kind is picked: the apps picker opens on the pick (#89).
    public static let kindLine = "Pick one, then choose its apps."
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
    /// A block waiting for Always location (#63).
    public static let needsAlways = "Needs Always location"
    public static let waiting = "Waiting"
    public static func waitsForAlways(_ block: String, place: String) -> String {
      "\(block) waits for Always location to know when you're at \(place)."
    }
    public static let withoutAlwaysTitle = "Without Always location"
    public static func withoutAlwaysBody(_ block: String, place: String, span: String) -> String {
      "\(Copy.name) can't tell when you're at \(place). \(block) can run \(span) wherever you are, or wait until location is set to Always."
    }
    public static func onlyAt(_ place: String) -> String { "Only at \(place)" }
    public static let runAnyway = "Run anyway"
    /// D37: without Always and Precise every block runs on its hours wherever the user is (#49).
    public static func placeIgnored(_ block: String, span: String) -> String {
      "Location is set to While Using, so \(block) runs \(span) wherever you are."
    }
    /// Save says when changes apply ("Save for after 5:00 pm"); the note doesn't repeat it.
    public static func activeNote(_ block: String, until time: String) -> String {
      "\(block) is on until \(time)."
    }
    public static func nightActiveNote(until time: String) -> String {
      "Your night is on until \(time)."
    }
    public static func nightPlaceIgnored(span: String) -> String {
      "Location is set to While Using, so your night runs \(span) wherever you are."
    }
    public static let sleepStays = "Your nights can be changed but not deleted."
    /// The apps row while it's empty: why Save is off (the audit).
    public static let chooseAppsToSave = "Choose apps to save"
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
      "With no place, this block starts and ends at its set times. Location isn't used."
    public static let building = "Building"
    /// Not "Block": that word is the app's (D57, one concept per word).
    public static let street = "Street"
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

    /// Over the night's day chips: a chip is the day a night starts (the audit).
    public static let nightsStarting = "Nights starting"
    /// Under them, which nights those are: "Sun–Thu night → Mon–Fri morning". A lone "S" could be
    /// either day, and Sunday-to-Thursday reads as Monday-to-Thursday on a Monday-first row.
    public static func nightSpan(_ days: Set<Weekday>, crossesMidnight: Bool) -> String? {
      guard !days.isEmpty else { return nil }
      if days == Weekday.all { return "Every night" }
      // Runs of days in a row, wrapping from Sunday to Monday.
      let order = Weekday.allCases
      guard let gap = order.firstIndex(where: { !days.contains($0) }) else { return nil }
      var runs: [(Weekday, Weekday)] = []
      for step in 1...7 {
        let day = order[(gap + step) % 7]
        guard days.contains(day) else { continue }
        if let last = runs.last, last.1.next == day {
          runs[runs.count - 1].1 = day
        } else {
          runs.append((day, day))
        }
      }
      runs.sort { $0.0 < $1.0 }
      func name(_ run: (Weekday, Weekday)) -> String {
        run.0 == run.1 ? Home.shortDay(run.0) : "\(Home.shortDay(run.0))–\(Home.shortDay(run.1))"
      }
      let starts = runs.map(name).joined(separator: ", ")
      guard crossesMidnight else { return starts }
      let ends = runs.map { name(($0.0.next, $0.1.next)) }.joined(separator: ", ")
      return "\(starts) night → \(ends) morning"
    }

    public static func refused(
      _ error: CommandError, maxApps: Int, maxBlocks: Int, maxName: Int
    ) -> String {
      switch error {
      case .tooManyApps: "Up to \(maxApps) apps and sites across all blocks."
      case .tooManyBlocks: "Up to \(maxBlocks) blocks."
      case .tooManyWindows:
        "Too many sets of hours across blocks. Use the same hours as another block."
      case .tooManyPlaces: "Too many places."
      case .invalidSchedule: "Choose hours at least 15 minutes long, on at least one day."
      case .invalidName: "Give it a name of up to \(maxName) characters."
      case .unknownPlace: "Choose the place again."
      case .sleepBlockCannotBeDeleted: sleepStays
      case .noSleepBlock: "Your nights are already set."
      case .readOnly: Home.readOnlyCard
      case .door: ""
      }
    }
  }
}
