import Foundation

extension Copy {
  /// The working name (decisions D35); every line that says it reads it from here.
  public static let name = "Dusk"
  /// Shown until StoreKit returns the localized price (decisions D34).
  public static let fallbackPrice = "$9.99"

  /// P-1 and D7: the whole deal, before anything else.
  public static func offer(price: String) -> String {
    "Seven nights free. Then \(price) once, or it switches off. No subscription."
  }

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
    public static let sleepName = "Sleep"
    public static let homeName = "Home"
    public static let `continue` = "Continue"
    public static let done = "Done"
    public static let tryAgain = "Try again"
    public static let openSettings = "Open Settings"

    public static let welcomeTitle = "Buy back your sleep."
    public static let welcomeLine =
      "At home, at night, the apps that keep you up stop opening. Everything else works."
    public static let offerTitle = "7 nights free"
    public static func offerDetail(price: String) -> String {
      "Then \(price) once, or it switches off. No subscription."
    }
    public static let start = "Start my free week"
    public static let restore = "Already bought it? Restore"

    public static let wakeTitle = "When do you need to be up?"
    public static let weekendWakeTitle = "On weekends?"
    public static let yourNights = "Your nights"
    public static let weekendNights = "Friday and Saturday nights"
    public static func nights(_ window: TimeWindow, in calendar: Calendar = .current) -> String {
      "\(span(window, in: calendar)) · \(length(minutes: window.minutes))"
    }
    public static let change = "Change"
    public static let nightsStart = "Nights start at"
    public static let differentOnWeekends = "Different on weekends"
    public static let weekendWake = "Weekend wake time"
    public static let sleepAdvice = "Most adults need 7 to 9 hours. You can change this any time."

    public static let homeTitle = "Where do you sleep?"
    public static let currentLocation = "Your current location"
    public static let coversBuilding = "The block covers this building"
    public static let movingDetail = "Drag the map to put home in the circle"
    public static let move = "Move"
    public static let homeLine =
      "\(name) only checks whether you're home. It never keeps a record of where you go."
    public static let thisIsHome = "This is home"
    public static let finding = "Finding where you are…"
    public static let noFix = "No exact location yet. Try again by a window or outside."
    public static let homeWithoutLocation =
      "Without location, your blocks run on their hours, wherever you are."
    public static let continueWithout = "Continue without location"
    public static let mapLabel = "Map of where you are, with home drawn as a circle"
    public static let mapPin = "Home"

    public static let permissionsTitle = "Two permissions"
    public static let permissionsLine =
      "Both are Apple's screens. You can see and change them in Settings."
    public static let screenTime = "Screen Time"
    public static let screenTimeWhy = "To block apps at night"
    public static let location = "Location, set to Always"
    public static let locationWhy = "To know when you're home, even when the app is closed"
    public static let allow = "Allow"
    public static let allowed = "Allowed"
    public static let screenTimeNeeded = "Not allowed. Without Screen Time nothing can be blocked."
    public static let locationDenied =
      "Not allowed. Your blocks will run on their hours, wherever you are."
    public static let locationApproximate =
      "Precise Location is off. Your blocks will run on their hours, wherever you are."

    public static let alwaysTitle = "One more step: choose Always"
    public static let alwaysLine =
      "Location is set to While Using. With that, \(name) can't tell you're home while it's closed, so your blocks run on their hours, wherever you are."
    public static let alwaysHeader = "Allow location access"
    public static let alwaysOptions = ["Never", "Ask Next Time", "While Using the App"]
    public static let alwaysChoice = "Always"
    public static let alwaysPath = "In Settings: \(name) → Location → Always."
    public static let alwaysLater = "Not now. Blocks run on their hours alone."

    public static let blockTitle = "What keeps you up?"
    public static let blockLine = "These apps won't open at night. Everything else works as normal."
    public static let chooseApps = "Choose apps"
    public static let chooseMore = "Choose more"
    public static let pickerNote =
      "You pick from Apple's list. You can add a whole category, like Social, at once."
    public static func tooMany(_ max: Int) -> String {
      "Up to \(max) apps and sites across all blocks. Choose fewer, or a whole category."
    }

    public static let readyTitle = "You're set"
    public static func readyLine(_ start: String, atHome: Bool) -> String {
      atHome ? "Tonight at \(start), if you're home." : "Tonight at \(start)."
    }
    public static func readyNow(_ end: String, atHome: Bool) -> String {
      atHome ? "From now until \(end), if you're home." : "From now until \(end)."
    }
    public static let everyNight = "Every night"
    public static let weekendsDiffer = "Weekends differ"
    public static let atHome = "At home"
    public static let yourBuilding = "Your current building"
    public static let anywhere = "Anywhere"
    public static let blocked = "Blocked"
    public static func blockedCount(apps: Int, categories: Int) -> String {
      var parts: [String] = []
      if apps > 0 { parts.append(apps == 1 ? "1 app" : "\(apps) apps") }
      if categories > 0 {
        parts.append(categories == 1 ? "1 category" : "\(categories) categories")
      }
      return parts.joined(separator: middleDot)
    }
    public static func unlocks(_ n: Int) -> String { n == 1 ? "1 unlock" : "\(n) unlocks" }
    public static func unlocksDetail(minutes: Int) -> String {
      "Open one app for \(minutes) minutes"
    }
    public static func freeUntil(_ day: String, price: String) -> String {
      "Free until the morning of \(day). Then \(price) once, or it switches off."
    }
  }
}
