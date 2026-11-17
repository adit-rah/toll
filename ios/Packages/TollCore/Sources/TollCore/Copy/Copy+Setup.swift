import Foundation

extension Copy {
  /// The product name is not chosen (spec header); every line that says it reads it from here.
  public static let name = "Toll"
  /// Shown until StoreKit returns the localized price (step 7).
  public static let fallbackPrice = "$24.99"

  /// P-1: the same words on the first screen and in the store listing.
  public static func offer(price: String) -> String {
    "Seven nights free. Then \(price) once, or it switches off. No subscription."
  }

  public enum Setup {
    public static func step(_ index: Int, of count: Int) -> String { "Step \(index) of \(count)" }

    public static let start = "Start"
    public static let `continue` = "Continue"

    public static let wakeTitle = "When do you get up?"
    public static func nights(_ window: SleepWindow, in calendar: Calendar = .current) -> String {
      "Your nights: \(Copy.window(window, in: calendar))"
    }
    public static let nightsStart = "Nights start at"
    public static let changeStart = "Change"

    public static let homeTitle = "Where do you sleep?"
    public static let homeLine =
      "\(name) only checks whether you are home. It never records where you go."
    public static let thisIsHome = "This is home"
    public static let finding = "Finding where you are…"
    public static let noFix = "No exact location yet. Try again by a window or outside."
    public static let tryAgain = "Try again"
    public static let homeWithoutLocation =
      "Without location, the block runs every night in your sleep window, wherever you are."
    public static let continueWithout = "Continue without location"
    public static let mapLabel = "Map of where you are, with home drawn as a circle"

    public static let permissionsTitle = "\(name) needs two things"
    public static let screenTime = "Screen Time"
    public static let location = "Location"
    public static let allow = "Allow"
    public static let allowed = "Allowed"
    public static let screenTimeNeeded = "Not allowed. Without Screen Time nothing can be blocked."
    public static let screenTimeWhy = "To block apps at night"
    public static let locationWhy = "To check whether you are home"
    public static let locationAlwaysNeeded =
      "Set to While Using. To check from home while \(name) is closed, choose Always in Settings."
    public static let locationApproximate =
      "Precise Location is off. Turn it on in Settings, or the block runs every night wherever you are."
    public static let locationDenied =
      "Not allowed. The block will run every night in your sleep window, wherever you are."
    public static let openSettings = "Open Settings"

    public static let keepOpenTitle = "What should still work at night?"
    public static let keepOpenLine = "Most people keep messages, maps, music and the clock."
    public static let choose = "Choose"
    public static let chooseAgain = "Change"
    public static let done = "Done"
    public static let categoriesNotKept =
      "Whole categories cannot stay open. Choose the apps inside them instead."

    public static func readyTitle(_ start: String, windowOnly: Bool) -> String {
      windowOnly ? "Tonight at \(start)." : "Tonight at \(start), if you're home."
    }
    public static func readyNow(_ end: String, windowOnly: Bool) -> String {
      windowOnly ? "From now until \(end)." : "From now until \(end), if you're home."
    }
    public static let ok = "OK"
  }
}
