import Foundation

extension Copy {
  /// The working name (decisions D35); every line that says it reads it from here.
  public static let name = "Dusk"
  /// Shown until StoreKit returns the localized price (decisions D34).
  public static let fallbackPrice = "$9.99"

  /// Hours and minutes of a window: "8 h 30 m".
  public static func length(minutes: Int) -> String {
    let hours = minutes / 60
    let rest = minutes % 60
    return rest == 0 ? "\(hours) h" : "\(hours) h \(rest) m"
  }

  /// "10:30 pm – 7:00 am". `short` reads "9 am – 5 pm" when both ends are whole hours, as Home's rows
  /// do; one half-hour keeps both ends long so they read alike.
  public static func span(
    _ window: TimeWindow, in calendar: Calendar = .current, short: Bool = false
  ) -> String {
    let whole = short && window.start.minute == 0 && window.end.minute == 0
    return
      "\(time(window.start, in: calendar, short: whole)) – \(time(window.end, in: calendar, short: whole))"
  }

  /// The canvas's onboarding, as amended by docs/design-brief.md.
  public enum Setup {
    public static func step(_ index: Int, of count: Int) -> String { "Step \(index) of \(count)" }
    /// The night's block's stored name; people never see it as a block's name (D68).
    public static let nightName = "Night"
    public static let homeName = "Home"
    public static let `continue` = "Continue"
    public static let done = "Done"
    public static let tryAgain = "Try again"
    public static let openSettings = "Open Settings"

    public static let welcomeTitle = "Your nights, phone-free."
    public static let welcomeLine =
      "At night, the apps that keep you up stop opening. Everything else works."
    public static let offerTitle = "14 nights free"
    public static func offerDetail(price: String) -> String {
      "Then \(price) once. No subscription. No account."
    }

    /// When this phone's or Apple ID's free nights are used, or bought (#46, D78).
    public static let setUp = "Set up \(name)"
    public static let offerUsedTitle = "Free nights used"
    public static func offerUsedDetail(_ day: String, price: String) -> String {
      "It ended \(day) on this phone. \(price) once, no subscription."
    }
    public static let offerPurchasedTitle = "Purchased"
    public static let offerPurchasedDetail = "Every night is yours. No subscription."
    public static let restore = "Already bought it? Restore"

    public static let weeknights = "Weeknights"
    public static let weekendNights = "Fri and Sat nights"
    public static let differentOnWeekends = "Different on weekends"
    /// Between the moon and the sun (D68): "10:30 pm – 7:00 am".
    public static func nightSpan(start: String, end: String) -> String { "\(start) – \(end)" }
    /// The night drawn as moon start – end sun (D68), read out in one line.
    public static func nightLabel(start: String, end: String) -> String {
      "Night, \(start) to \(end)"
    }

    public static let homeTitle = "Where do you sleep?"
    public static let currentLocation = "Your current location"
    public static let coversBuilding = "This building and the street around it"
    public static let movingDetail = "Drag the map to put home in the circle"
    public static let move = "Move"
    public static let homeLine = "Location only tells \(name) whether you're home. We never see it."
    public static let thisIsHome = "This is home"
    public static let finding = "Finding where you are…"
    public static let noFix = "No exact location yet. Try again by a window or outside."
    public static let homeWithoutLocation =
      "Location is off, so your night starts and ends at its set times, wherever you are. Turn it on in Settings to set home."
    public static let notNow = "Not now"
    public static let cancel = "Cancel"
    public static let mapLabel = "Map of where you are, with home drawn as a circle"
    public static let mapPin = "Home"

    /// Onboarding asks for Screen Time alone (D68); location comes later, with home.
    public static let screenTimeTitle = "Allow Screen Time"
    public static let screenTimeLine =
      "Apple asks next. It's how \(name) keeps apps closed at night. You can change it in Settings."
    public static let screenTime = "Screen Time"
    public static let screenTimeWhy = "To block apps at night"
    public static let locationTitle = "Allow location"
    public static let locationLine =
      "Apple asks next. With Always, your night starts when you get home."
    public static let location = "Location"
    public static let locationWhy = "So your night starts when you're home"
    public static let allow = "Allow"
    /// A permission's state, as Settings words it.
    public static let off = "Off"
    public static let on = "On"
    public static let always = "Always"
    public static let whileUsing = "While Using"
    public static let preciseLocation = "Precise Location"
    public static let screenTimeDenied =
      "Without Screen Time, \(name) can't block anything. Tap Try again and choose Continue, or turn it on in Settings › Screen Time."

    public static let alwaysTitle = "Choose Always"
    public static let alwaysLine =
      "Location is set to While Using. With Always, your night starts only when you're home. Without it, your night starts and ends at its set times, wherever you are."
    public static let alwaysHeader = "Allow location access"
    public static let alwaysOptions = ["Never", "Ask Next Time", "While Using the App"]
    public static let alwaysChoice = "Always"
    public static let alwaysPath = "In Settings: \(name) › Location › Always."
    public static let alwaysLater = "Not now. Use the set times."

    /// About the night: onboarding and Tonight don't mention other blocks (D68).
    public static let locationOffTitle = "Your night keeps its set times"
    public static let whileUsingFact =
      "Location is set to While Using. Your night starts and ends at its set times, wherever you are."
    public static let approximateFact =
      "Precise Location is off. Your night starts and ends at its set times, wherever you are."
    public static let deniedFact =
      "Location is off. Your night starts and ends at its set times, wherever you are."
    public static let changeInSettings = "Change in Settings"

    public static let blockTitle = "What keeps you up?"
    public static let blockLine = "These apps won't open at night. Everything else works as normal."
    public static let chooseApps = "Choose apps"
    public static let chooseMore = "Choose more"
    public static let pickerNote =
      "You pick from Apple's list. You can add a whole category, like Social, at once."
    public static func tooMany(_ max: Int) -> String {
      "Up to \(max) apps and sites. Choose fewer, or a whole category."
    }

    public static let readyEyebrow = "You're set"
    /// The lock, which starts the gap before bed (D76); bed is on the night's picture.
    public static func readyLine(_ lock: String) -> String { "Apps lock at \(lock) tonight." }
    public static func readyNow(_ end: String) -> String { "From now until \(end)." }
    public static let anywhere = "Anywhere"
    public static let anywhereDetail = "At its set times, wherever you are"
    /// Ready, before home is set (D68): where tonight runs, and that home comes later.
    public static let anywhereUntilHome =
      "Wherever you are. You can add home after the first night."
    public static let blocked = "Blocked"
    /// "2 categories · 2 apps": counts, because iOS never tells the app the names (D41).
    public static func blockedCount(categories: Int, apps: Int, sites: Int = 0) -> String {
      var parts: [String] = []
      if categories > 0 {
        parts.append(categories == 1 ? "1 category" : "\(categories) categories")
      }
      if apps > 0 { parts.append(apps == 1 ? "1 app" : "\(apps) apps") }
      if sites > 0 { parts.append(sites == 1 ? "1 site" : "\(sites) sites") }
      return parts.joined(separator: middleDot)
    }
    public static func unlocks(_ n: Int) -> String {
      n == 1 ? "1 pause a week" : "\(n) pauses a week"
    }
    public static func unlocksDetail(minutes: Int) -> String {
      "Every app opens for \(minutes) minutes"
    }
    public static func freeNightsEnded(_ day: String, price: String) -> String {
      "Your free nights ended \(day). Nothing is blocked until the \(price) purchase."
    }
    public static func freeUntil(_ day: String, price: String) -> String {
      "Free until the morning of \(day). Then \(price) once, or it switches off."
    }
  }
}
