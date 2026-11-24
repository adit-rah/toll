import Foundation

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
    public static let footnote = "Without it, nothing is blocked. Everything you set up stays."
    public static func usedLabel(_ n: Int) -> String { n == 1 ? "pause used" : "pauses used" }

    /// After buying (#77; founders, 21 Nov).
    public static let doneTitle = "Every night is yours"
    public static let done = "Done"
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
