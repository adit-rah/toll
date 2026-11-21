import Foundation

extension Copy {
  public enum Door {
    public static func unlocksLeft(_ left: Int, of max: Int) -> String {
      "Unlocks left: \(left) of \(max)"
    }
    /// Only nights Sleep ran count toward the refill (#61), so the copy says "blocked nights".
    public static func refill(after nights: Int) -> String {
      nights == 1
        ? "One returns after 1 more blocked night without using any."
        : "One returns after \(nights) more blocked nights without using any."
    }
    public static func noneLeft(nights: Int) -> String {
      nights == 1
        ? "No unlocks left. One returns after 1 blocked night without using any."
        : "No unlocks left. One returns after \(nights) blocked nights without using any."
    }

    public static func question(minutes: Int) -> String { "Open one app for \(minutes) minutes?" }
    public static let notNow = "Not now"
    public static let chooseApp = "Choose app"
    public static func openFor(minutes: Int) -> String { "Open for \(minutes) minutes?" }
    public static let startWait = "Start the wait"
    public static let chooseDifferent = "Choose a different app"
    public static let chooseOneTitle = "Choose one app"
    public static func pickedSeveral(_ n: Int) -> String {
      "You picked \(n). The door opens one app at a time."
    }
    public static let pickedCategory =
      "You picked a whole category. The door opens one app at a time."
    public static let chooseAgain = "Choose again"
    public static func unlocksOf(_ left: Int, _ max: Int) -> String {
      "\(left) of \(max) unlocks left"
    }
    public static func waitFirst(seconds: Int) -> String {
      "You wait \(seconds) seconds first. Cancelling costs nothing."
    }
    public static func onceWaitEnds(minutes: Int) -> String {
      "Opens for \(minutes) minutes when the wait ends"
    }
    public static let leaveFreely = "You can leave this screen. The wait keeps going."
    public static let isOpen = "Open now"
    public static func locksAt(_ time: String) -> String { "Locks again at \(time)" }
    public static let leftWord = "left"
    public static func regretFor(_ clock: String) -> String {
      "Lock again in the next \(clock) and you keep the unlock."
    }
    public static let noneTitle = "No unlocks left"
    public static func noneOf(_ max: Int) -> String { "0 of \(max)" }
    public static func refillLine(_ nights: Int, after: Int) -> String {
      "One comes back after \(after) blocked nights without using any. \(nights) \(nights == 1 ? "night" : "nights") to go."
    }
    public static let othersWork = "Everything you didn't block still works."
    public static let fromHomeScreen = "Open it from your Home Screen."
    public static let notBlockedTitle = "That app isn't blocked right now"
    public static let notBlockedBody =
      "It opens as usual, so no unlock was used. Pick one of the apps you blocked."
    public static let ok = "OK"

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

    public static func open(minutes: Int) -> String { "Open for \(minutes) minutes." }
    public static func left(_ clock: String) -> String { "\(clock) left" }
    public static func leftSpoken(minutes: Int, seconds: Int) -> String {
      switch (minutes, seconds) {
      case (0, let s): "\(s) seconds left"
      case (let m, 0): m == 1 ? "1 minute left" : "\(m) minutes left"
      case (let m, let s): "\(m) minute\(m == 1 ? "" : "s") \(s) seconds left"
      }
    }
    public static let lockAgain = "Lock again"
    /// D-4: said here and nowhere else.
    public static func regret(minutes: Int) -> String {
      "Lock again in the next \(minutes) minutes and you keep the unlock."
    }
  }
}
