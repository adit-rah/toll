import Foundation

extension Copy {
  /// Home, in every state (the design canvas, amended by docs/design-brief.md).
  public enum Home {
    public static let settings = "Settings"
    /// Tonight's name on the back button of the screens it opens: the tab's name, since "Home" is
    /// also the place (D75).
    public static let backTitle = Tabs.tonight
    public static func nightPill(_ night: Int, of nights: Int) -> String {
      "Night \(night) of \(nights) free"
    }
    public static let lastNightPill = "Last free night tonight"
    /// What a tap on the free nights pill does, for VoiceOver (D75).
    public static let pillHint = "Shows your free nights and the price"

    public static let tonight = "Tonight"
    public static let today = "Today"
    /// Over the big time, what it means (D75): when the apps lock, until when they're locked.
    public static let locksAt = "Apps lock at"
    public static let locksTomorrowAt = "Apps lock tomorrow at"
    /// A start that isn't tonight: "Apps lock Monday at".
    public static func locksOn(_ day: String) -> String { "Apps lock \(day) at" }
    public static let blockedUntil = "Apps locked until"
    /// A pause is open (D67): until it ends, then the night goes on.
    public static let pausedUntil = "Paused until"
    public static func thenLockedUntil(_ time: String) -> String { "Then locked until \(time)" }
    /// Away in the night's hours: the big time is the night's end.
    public static let nightEndsAt = "Night ends at"
    public static let locksWhenHome = Strip.whenHome
    /// After the free week (D70, D74): what's off is the app, said with its name.
    public static let isOff = "\(name) is off"
    public static let yourNight = Strip.yourNight
    public static let noBlocks = "Nothing scheduled"
    /// The way forward from "Nothing scheduled": the night's editor.
    public static let setNight = "Set your night"
    /// Tonight's one line about another block, while it's on (D68, #89).
    public static func otherBlockOn(_ block: String, until time: String) -> String {
      "\(block) on until \(time)"
    }
    public static func otherBlocksOn(_ count: Int, until time: String) -> String {
      "\(count) blocks on until \(time)"
    }

    public static func startsIn(_ duration: String, atHome: Bool) -> String {
      atHome ? "At home · starts in \(duration)" : "Starts in \(duration)"
    }
    /// Under "Apps locked until" at home. The pauses are said beside their dots, with their week.
    public static let youreHome = "You're home"
    public static let noUnlocksLeft = "No pauses left"
    /// Home not set (D68): the place line says where tonight runs, plainly.
    public static func anywhereStartsIn(_ duration: String) -> String {
      "Anywhere · starts in \(duration)"
    }
    /// The Tonight card that offers home, from the morning after the first night (D68, #102).
    public static let homeCard = "Only when I'm home?"
    public static let homeCardDetail = "Your night starts when you get home, not before."
    public static let setHome = "Set home"
    public static let notNow = Setup.notNow
    public static let onNow = "On now"
    public static let notBlocking = "Not blocking"
    public static let trialEnded = "Your free nights ended."
    public static let trialEndedToday = "Your free nights ended this morning."
    /// "Every night after" read as a charge each night.
    public static func onceEveryNight(_ price: String) -> String {
      "\(price) once, for good"
    }
    public static let noBlockSpoken = "no block"
    public static let missedSpoken = "not blocked"
    public static let awaySpoken = "away, nothing blocked"
    public static let offNight = "off"
    public static let noScreenTimeSpoken = "Screen Time off, nothing blocked"
    public static let blockedSpoken = "blocked"
    public static let aheadSpoken = "still to come"
    public static let now = "Now"
    public static func unlocksLeft(_ n: Int) -> String {
      n == 1 ? "1 pause left" : "\(n) pauses left"
    }
    /// The quiet capsule beside the dots (D61, D67).
    public static let pause = "Pause"
    /// The capsule's VoiceOver label: "Pause" alone has no object.
    public static let pauseSpoken = "Pause blocking"
    /// While a pause is open, on the hero: locks now, as the pause sheet's button does.
    public static let lockAgain = Door.lockAgain
    public static let turnBackOn = "Turn \(name) back on"
    public static func once(_ price: String) -> String { "\(price) once" }

    public static let locationBanner = Setup.whileUsingFact
    /// D37: running without location is a fact, not a fault (#45).
    public static let fixInSettings = Copy.Setup.changeInSettings
    public static let screenTimeOffEyebrow = "Screen Time is off"
    /// The card above says how to turn it on; the hero says only what's true tonight.
    public static let screenTimeOffDetail = "Nothing blocks tonight"
    public static let screenTimeOffCard = "Screen Time is off for Dusk. Nothing can be blocked."
    public static let turnOn = "Turn on"
    /// The night came back from its record without its apps (#140).
    public static let recoveredCard =
      "Dusk couldn't read its settings and kept your night. Choose your apps again."
    public static let chooseApps = Setup.chooseApps
    /// A TestFlight build older than the one that last wrote the state file (#140).
    public static let readOnlyCard =
      "This version of Dusk can't save changes. Update it in TestFlight."

    public static let thisWeek = "This week"
    public static let seeAll = "See all"
    /// Under a count of nights, never "of 7": a shortfall isn't shown (D65). Says what was counted,
    /// not "phone-free", which read as time off the phone (D75).
    public static func nightsLabel(_ n: Int) -> String {
      n == 1 ? "night with apps locked" : "nights with apps locked"
    }
    /// "Never mind" taps, about the person rather than the app's work (D65), in the founder's words.
    public static func putDownLabel(_ n: Int) -> String {
      n == 1 ? "time you chose sleep" : "times you chose sleep"
    }

    public static let blocks = "Blocks"
    public static let new = "New"
    public static let weekdays = "Weekdays"
    public static let weekends = "Weekends"
    public static let everyDay = "Every day"
    /// After the free week, and a block that's switched off: nothing blocks (D70). Never "Paused",
    /// which is the pause's word (D57, D67).
    public static let off = "Off"
    public static let weekendsDiffer = "Weekends differ"
    public static func shortDay(_ day: Weekday) -> String {
      ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][day.rawValue - 1]
    }

    /// "3 h 12 m", "45 m"; past a day, "2 d 7 h" rather than "55 h 12 m" (D75).
    public static func duration(_ seconds: TimeInterval) -> String {
      let minutes = max(0, Int(seconds / 60))
      if minutes >= 1440 {
        let hours = (minutes % 1440) / 60
        return hours == 0 ? "\(minutes / 1440) d" : "\(minutes / 1440) d \(hours) h"
      }
      return minutes >= 60 ? length(minutes: minutes) : "\(minutes) m"
    }
  }
}

extension Copy {
  /// The tab bar (D63): Tonight is a glance, Your sleep the trends, Blocks the setup.
  public enum Tabs {
    public static let tonight = "Tonight"
    public static let sleep = "Your sleep"
    public static let blocks = "Blocks"
  }
}
