import Foundation

/// Personal timing (D66, D99): for a person who chose it, the sleep model moves the night's lock
/// start by one of a few offsets and holds it for a week, Monday to Sunday by the night's date, so
/// it can learn whether an earlier start helps them fall asleep sooner. Bed and wake never move;
/// only the lock's start does, inside the buffer before sleep. The draw itself is the app's
/// (`SleepModel.chooseStart`); this keeps what it chose, so every process locks and records alike.
public struct Timing: Codable, Hashable, Sendable {
  /// One week's start, as `SleepModel.Hold` names it and the night record logs it (D99).
  public struct Hold: Codable, Hashable, Sendable {
    /// The hold's first night, "yyyy-MM-dd", as night records key nights.
    public var start: String
    /// Minutes from the plan: negative locks earlier.
    public var offset: Int
    /// The exact chance the draw had, logged on every night of the hold.
    public var prob: Double
    /// Whether the person was settled when it was chosen.
    public var settled: Bool

    public init(start: String, offset: Int, prob: Double, settled: Bool) {
      self.start = start
      self.offset = offset
      self.prob = prob
      self.settled = settled
    }
  }

  /// From which night a hold was in force, or none, so a night record written late carries the
  /// start that night really had.
  public struct Entry: Codable, Hashable, Sendable {
    public var night: Date
    public var hold: Hold?

    public init(night: Date, hold: Hold?) {
      self.night = night
      self.hold = hold
    }
  }

  /// The person chose personal timing (D65); off until they do.
  public var on = false
  /// What the lock ran with, oldest first; the last is in force.
  public var history: [Entry] = []
  /// The model's generator (SplitMix64) after the last draw, as decimal text, so a draw lost
  /// before it was saved replays the same way. Nil until the first.
  public var generator: String?

  /// Entries kept: enough for any night the app records late.
  static let kept = 12

  public init() {}

  /// The hold the lock runs with now.
  public var inForce: Hold? { history.last?.hold }

  /// The latest hold drawn, in force or not.
  public var lastHold: Hold? { history.last { $0.hold != nil }?.hold }

  /// The hold a night ran with, from its key.
  public func hold(forNight night: Date) -> Hold? {
    history.last { $0.night <= night }?.hold
  }

  /// Puts a hold, or none, in force from `night` on.
  mutating func put(_ hold: Hold?, from night: Date) {
    guard hold != inForce else { return }
    history.removeAll { $0.night >= night }
    if history.isEmpty, hold == nil { return }
    history.append(Entry(night: night, hold: hold))
    if history.count > Self.kept { history.removeFirst(history.count - Self.kept) }
  }

  /// The week a night belongs to: whole weeks since 2001-01-01, a Monday, as
  /// `datascience/dusk_model/timing.py` and `SleepModel` count them. Nil for text that isn't a date.
  public static func week(_ night: String) -> Int? {
    let parts = night.split(separator: "-", omittingEmptySubsequences: false)
    guard parts.count == 3, let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]),
      (1...12).contains(m), (1...31).contains(d)
    else { return nil }
    let days = civilDays(y, m, d) - civilDays(2001, 1, 1)
    return days >= 0 ? days / 7 : (days - 6) / 7
  }

  /// Days since 1970-01-01 for a proleptic Gregorian date (Howard Hinnant's algorithm).
  static func civilDays(_ year: Int, _ month: Int, _ day: Int) -> Int {
    let y = month <= 2 ? year - 1 : year
    let era = (y >= 0 ? y : y - 399) / 400
    let yoe = y - era * 400
    let doy = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
    return era * 146_097 + doe - 719_468
  }

  /// The offsets a night may use with `before` minutes of buffer before sleep (D97, D101): the
  /// lock never starts after bed and never more than a person may choose by hand, and never earlier
  /// while the buffer is already past the target everyone grows toward. The plan is always allowed.
  public static func allowed(before: Int, config: TollConfig) -> [Int] {
    config.timing.offsets.filter { offset in
      let lead = before - offset
      guard offset != 0 else { return true }
      guard lead >= 0, lead <= config.gap.manualMax else { return false }
      return offset > 0 || before <= config.timing.earlierUpTo
    }
  }
}
