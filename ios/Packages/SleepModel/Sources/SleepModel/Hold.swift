/// Personal timing's start for a run of nights (decisions D66), as `dusk_model/timing.py`.
///
/// A hold is `hold` nights long, counted from 2001-01-01, a Monday, so a 7-night hold runs Monday to
/// Sunday by the night's date. On a hold's first night the person is settled if the insight shows
/// (the farthest allowed start on the side it supports) or, after `minNights` usable nights, if the
/// 90% range lies inside ±`settlePlanWithinMin` (the plan). Settling is checked afresh each hold. A
/// settled person keeps the settled start except in `settledExploreShare` of holds; anyone else draws
/// by Thompson sampling with the floor. A held start that stops being allowed is redrawn that night.
///
/// `prob` is the exact chance of the hold's draw given the history to its first night, logged on each
/// of its nights: unsettled, p'(start); settled, share · p'(start) + (1 − share) · [start is the
/// settled one]. The record names the hold by `start` and says whether it was `settled`.
public struct Hold: Codable, Sendable, Equatable {
  /// The hold's first night, "yyyy-mm-dd".
  public var start: String
  public var offset: Int
  public var prob: Double
  public var settled: Bool

  public init(start: String, offset: Int, prob: Double, settled: Bool) {
    self.start = start
    self.offset = offset
    self.prob = prob
    self.settled = settled
  }

  /// The hold to keep tonight from the night log (one record per night, in order): the latest
  /// night's, if a held policy chose it. A rebuild never moves a week's start.
  public static func latest(in records: [NightRecord]) -> Hold? { records.last?.hold }
}

extension NightRecord {
  /// The hold this night logged; nil for "fixed" and "thompson" nights.
  public var hold: Hold? {
    guard policy == "held", let holdStart else { return nil }
    return Hold(
      start: holdStart, offset: actionOffsetMin, prob: actionProb, settled: settled ?? false)
  }
}

extension SleepModel {
  /// Tonight's hold: `held` (last night's) while tonight is in its period and its start is allowed,
  /// else a new one. Draws, in order, only for a new hold: `probDraws` × 4 normals, a uniform for the
  /// pick, and, when the artifact settles, a uniform for exploring. A night that isn't a date keeps
  /// the plan, drawing nothing.
  public func chooseStart(
    night: String, _ context: NightContext, held: Hold?, rng: inout SeededRNG
  ) -> Hold {
    guard let tonight = Day.number(night) else {
      return Hold(start: night, offset: 0, prob: 1, settled: false)
    }
    let policy = artifact.policy
    let allowed = allowedStarts(context)
    if let held, let start = Day.number(held.start),
      Day.period(start, policy.hold) == Day.period(tonight, policy.hold),
      let k = artifact.actions.firstIndex(of: held.offset), allowed[k]
    {
      return held
    }
    let mixed = floored(context, allowed: allowed, rng: &rng)
    let k = Self.pick(mixed, allowed: allowed, u: rng.uniform())
    var offset = artifact.actions[k]
    guard policy.settles else {
      return Hold(start: night, offset: offset, prob: mixed[k], settled: false)
    }
    let share = policy.settledExploreShare ?? 0
    let explore = rng.uniform() < share
    guard let target = settledStart(allowed) else {
      return Hold(start: night, offset: offset, prob: mixed[k], settled: false)
    }
    if !explore { offset = target }
    let drawn = artifact.actions.firstIndex(of: offset).map { mixed[$0] } ?? 0
    let prob = share * drawn + (1.0 - share) * (offset == target ? 1 : 0)
    return Hold(start: night, offset: offset, prob: prob, settled: true)
  }

  /// Where a settled person's start sits, or nil if they aren't settled tonight.
  func settledStart(_ allowed: [Bool]) -> Int? {
    let check = insightCheck()
    if check.shown, artifact.policy.settleAtInsight ?? false {
      let reach = artifact.actions.indices.filter { allowed[$0] }.map { artifact.actions[$0] }
      // A positive effect means an earlier start helps: the farthest allowed start on that side.
      return (check.effect > 0 ? reach.min() : reach.max()) ?? 0
    }
    let band = artifact.policy.settlePlanWithinMin ?? 0
    if band > 0, state.nights >= artifact.insight.minNights, check.low > -band, check.high < band {
      return 0
    }
    return nil
  }
}

/// Nights by their date, for holds.
enum Day {
  /// 2001-01-01, a Monday, as days since 1970-01-01.
  static let epoch = LocalTime.daysFromCivil(2001, 1, 1)

  /// Days since `epoch` for "yyyy-mm-dd".
  static func number(_ text: String) -> Int? {
    let parts = text.split(separator: "-", omittingEmptySubsequences: false)
    guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
      let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]),
      (1...12).contains(m), (1...31).contains(d)
    else { return nil }
    return LocalTime.daysFromCivil(y, m, d) - epoch
  }

  /// Whole holds since `epoch`, rounding down as Python's `//` does.
  static func period(_ day: Int, _ hold: Int) -> Int {
    let q = day / hold
    return (day % hold != 0 && (day < 0) != (hold < 0)) ? q - 1 : q
  }
}
