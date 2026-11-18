import Foundation

extension Copy {
  public enum Door {
    public static func unlocksLeft(_ left: Int, of max: Int) -> String {
      "Unlocks left: \(left) of \(max)"
    }
    public static func refill(after nights: Int) -> String {
      nights == 1
        ? "One returns after 1 more night without using any."
        : "One returns after \(nights) more nights without using any."
    }
    public static func noneLeft(nights: Int) -> String {
      nights == 1
        ? "No unlocks left. One returns after 1 night without using any."
        : "No unlocks left. One returns after \(nights) nights without using any."
    }

    public static func question(minutes: Int) -> String { "Open one app for \(minutes) minutes?" }
    public static let notNow = "Not now"
    public static let chooseOne = "Choose one app."
    /// For an app inside a blocked category, which the list cannot show by itself.
    public static let anotherApp = "Another app"

    public static func opensIn(_ clock: String) -> String { "Opens in \(clock)." }
    public static func opensInSpoken(minutes: Int, seconds: Int) -> String {
      switch (minutes, seconds) {
      case (0, let s): "Opens in \(s) seconds."
      case (let m, 0): m == 1 ? "Opens in 1 minute." : "Opens in \(m) minutes."
      case (let m, let s): "Opens in \(m) minute\(m == 1 ? "" : "s") \(s) seconds."
      }
    }
    public static let cancel = "Cancel"
    public static let cancelFree = "Cancelling costs nothing."

    public static func open(minutes: Int) -> String { "Open for \(minutes) minutes of use." }
    public static let lockAgain = "Lock again"
    /// D-4: said here and nowhere else.
    public static func regret(minutes: Int) -> String {
      "Lock again in the next \(minutes) minutes and you keep the unlock."
    }
  }
}
