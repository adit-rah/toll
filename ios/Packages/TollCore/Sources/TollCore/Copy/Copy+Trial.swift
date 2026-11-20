import Foundation

extension Copy {
  public enum Trial {
    /// P-5: the only mention before the trial ends.
    public static func night(_ night: Int, of nights: Int) -> String {
      "Night \(night) of \(nights) free."
    }

    public static let endedTitle = "Seven nights."
    public static func nightsBlocked(_ n: Int) -> String {
      n == 1 ? "Blocked at home: 1 night" : "Blocked at home: \(n) nights"
    }
    public static func blockScreens(_ n: Int) -> String {
      n == 1 ? "Block screen came up: 1 time" : "Block screen came up: \(n) times"
    }
    public static func unlocksUsed(_ n: Int) -> String {
      n == 1 ? "Unlocks used: 1" : "Unlocks used: \(n)"
    }
    public static func keep(price: String) -> String { "Keep it — \(price) once" }
    public static let restore = "Restore purchase"
    public static let without = "Without it, nothing is blocked."
    public static let pending = "Waiting for approval."
    public static let failed = "The purchase did not go through."
    public static let nothingToRestore = "No purchase found for this Apple Account."
  }
}

extension Copy {
  /// The purchase sheet (the design canvas): the week's facts, what it keeps, the price.
  public enum Purchase {
    public static let eyebrow = "Your free week"
    public static let title = "Keep your nights."
    public static let benefits = [
      "Every night, for good", "No subscription, ever", "No account",
      "No servers. We never see your data",
    ]
    public static let once = "once"
    public static let keep = "Keep it"
    public static let restore = "Restore purchase"
    public static let notNow = "Not now"
    public static let footnote = "Without it, nothing is blocked. Your blocks and settings stay."
    public static let unlocksUsedLabel = "unlocks used"
    public static func usedLabel(_ n: Int) -> String { n == 1 ? "unlock used" : "unlocks used" }

    public static let pendingTitle = "Waiting for approval"
    /// During the trial nothing is off yet (#48).
    public static let pendingTrialBody =
      "Someone in your family group needs to approve this. Your free nights continue until then."
    public static let pendingBody =
      "Someone in your family group needs to approve this. \(name) turns back on as soon as they do."
    public static let failedTitle = "The purchase didn't go through"
    public static let failedBody =
      "Nothing was charged. Check your payment details in Settings › Apple Account, then try again."
    public static let tryAgain = "Try again"
    public static let restoreNoneTitle = "No purchase found"
    public static let restoreNoneBody =
      "This Apple Account hasn't bought \(name). If you used a different one, sign in with it in Settings, then restore again."
    public static let ok = "OK"
  }
}
