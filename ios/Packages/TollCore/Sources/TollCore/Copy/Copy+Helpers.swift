import Foundation

extension Copy {
  /// Before bed's three helpers, in the gap between the lock and bed (D80). Plain and short; each
  /// ends with the phone down. Never a task, never counted.
  public enum Helpers {
    /// Tonight's quiet capsule, beside the pauses, only in the gap.
    public static let capsule = "Before bed"
    public static let capsuleHint = "A list on paper, slow breathing or a word game"

    /// The one card that introduces the capsule; the minutes are those left until bed.
    public static func card(minutes: Int) -> String {
      minutes == 1 ? "Something for the next minute?" : "Something for the next \(minutes) minutes?"
    }
    public static let cardDetail = "A list on paper, slow breathing or a word game."
    public static let showMe = "Show me"

    /// The sheet's choices.
    public static let sheetTitle = "Before bed"
    public static let sheetBody = "Pick one. Each ends with the phone down."
    public static let list = "Write tomorrow's list"
    public static let listDetail = "On paper, about five minutes"
    public static func breathe(minutes: Int) -> String {
      minutes == 1 ? "Breathe for 1 minute" : "Breathe for \(minutes) minutes"
    }
    public static let breatheDetail = "A soft tone, with the screen off"
    public static let words = "Try this in bed"
    public static let wordsDetail = "A word game, eyes closed"

    /// Each choice's page.
    public static let listTitle = "Tomorrow's list, on paper"
    public static let listBody =
      "Five minutes. Everything you need to do in the next few days, as specific as you can. Then put the phone down."
    public static let breatheBody =
      "Lock your phone and put it down. Breathe in as the tone rises, out as it falls."
    public static func toneUntil(_ time: String) -> String { "The tone fades out at \(time)" }
    public static let toneEnded = "The tone has ended."
    public static let stopTone = "Stop the tone"
    public static let wordsBody =
      "Pick a word, like “candle”. Take its first letter and picture things that start with it: a cat, a cup, a canoe. When they run out, move to the next letter."
    public static let wordsEnd = "Put the phone down and try it with your eyes closed."
    public static let done = "Done"
    public static let somethingElse = "Something else"

    /// Settings › Before bed, under the gap.
    public static let setting = "Something to do before bed"
    public static let settingDetail =
      "On Tonight after apps lock: a list on paper, slow breathing or a word game."
    public static func breathLength(_ minutes: Int) -> String { "Breathing tone · \(minutes) min" }
  }
}
