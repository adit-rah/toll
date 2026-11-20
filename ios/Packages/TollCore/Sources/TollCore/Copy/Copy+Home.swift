import Foundation

extension Copy {
  /// Home, in every state (the design canvas, amended by docs/design-brief.md).
  public enum Home {
    public static let settings = "Settings"
    /// Home's name on the back button of the screens it opens.
    public static let backTitle = "Home"
    public static func nightPill(_ night: Int, of nights: Int) -> String {
      "Night \(night) of \(nights) free"
    }
    public static let lastNightPill = "Last free night tonight"

    public static let tonight = "Tonight"
    public static let today = "Today"
    public static let blockedUntil = "Blocked until"
    public static let awayLabel = "Away from home"
    public static let paused = "Paused"
    public static let noBlocks = "No blocks"
    public static func blockUntil(_ block: String) -> String { "\(block) until" }

    public static func startsIn(_ duration: String, atHome: Bool) -> String {
      atHome ? "At home · starts in \(duration)" : "Starts in \(duration)"
    }
    public static let youreHome = "You're home"
    /// "You're home · 3 unlocks left" under "Blocked until".
    public static func blockedDetail(atHome: Bool, unlocksLeft: Int) -> String {
      "\(atHome ? youreHome : onNow)\(middleDot)\(unlocksLeft == 0 ? noUnlocksLeft : Self.unlocksLeft(unlocksLeft))"
    }
    public static let noUnlocksLeft = "No unlocks left"
    /// Without location (D37): "Starts at 10:30 pm, wherever you are".
    public static func startsAtAnywhere(_ time: String) -> String {
      "Starts at \(time), wherever you are"
    }
    public static let onNow = "On now"
    public static let startsWhenHome = "Starts when you're home"
    public static let notBlocking = "Not blocking"
    public static let trialEnded = "Your free week ended."
    public static let trialEndedToday = "Your free week ended this morning."
    public static func onceEveryNight(_ price: String) -> String {
      "\(price) once · every night after"
    }
    public static let noBlockNight = "–"
    public static let noBlockSpoken = "no block"
    public static let aheadSpoken = "still to come"
    public static let now = "Now"
    public static func change(_ delta: Int) -> String { delta < 0 ? "▼ \(-delta)" : "▲ \(delta)" }
    public static func changeSpoken(_ delta: Int) -> String {
      delta < 0 ? "\(-delta) fewer than the week before" : "\(delta) more than the week before"
    }
    public static func unlocksLeft(_ n: Int) -> String {
      n == 1 ? "1 unlock left" : "\(n) unlocks left"
    }
    public static let openOneApp = "Open one app"
    public static let turnBackOn = "Turn it back on"
    public static func once(_ price: String) -> String { "\(price) once" }

    public static let locationBanner =
      "Location is set to While Using. Your blocks run on their hours, wherever you are."
    public static let fixInSettings = "Fix in Settings"

    public static let thisWeek = "This week"
    public static let seeAll = "See all"
    public static func nightsBlocked(_ blocked: Int, of nights: Int) -> String {
      "\(blocked) of \(nights)"
    }
    public static let nightsBlockedLabel = "nights blocked"
    public static let stoppedLabel = "times it stopped you"
    public static let byNight = "Times it stopped you, by night"
    public static let trendsLater = "Your trends show here after 3 nights."
    public static func nightsSoFar(_ n: Int) -> String {
      n == 1 ? "1 night blocked" : "\(n) nights blocked"
    }

    public static let blocks = "Blocks"
    public static let new = "New"
    public static let weekdays = "Weekdays"
    public static let weekends = "Weekends"
    public static let everyDay = "Every day"
    public static let off = "Off"
    public static let weekendsDiffer = "Weekends differ"
    public static func shortDay(_ day: Weekday) -> String {
      ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][day.rawValue - 1]
    }

    /// "3 h 12 m", "45 m".
    public static func duration(_ seconds: TimeInterval) -> String {
      let minutes = max(0, Int(seconds / 60))
      return minutes >= 60 ? length(minutes: minutes) : "\(minutes) m"
    }

    public static func timelineLabel(start: String, end: String) -> String {
      "Tonight's block, \(start) to \(end)"
    }
  }
}
