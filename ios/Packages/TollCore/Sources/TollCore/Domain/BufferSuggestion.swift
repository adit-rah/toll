import Foundation

/// What each buffer should grow toward (#145). With too few of the person's own weeks it's the
/// recommended baseline (D97), the same for everyone. Once a side has `suggestion.minWeeks` judged
/// weeks, its target is fitted from them: below a level the person kept finding hard, the baseline
/// otherwise, and past it before sleep only for someone who sailed through the baseline and whose
/// Health sleep comes well after their planned sleep. Always inside the founder's bounds: before
/// sleep 30 to 90, after waking 15 to 30. `datascience/economy/suggest.py` is the reference; the
/// fixtures keep the two equal.
public struct BufferSuggestion: Equatable, Sendable {
  public var before: Int
  public var after: Int
  /// The sides whose target came from the person's own weeks; the others are the baseline.
  public var fitted: Set<Gap.Side> = []

  /// The baseline: what a new person is offered.
  public init(config: TollConfig = .defaults) {
    before = config.suggestion.before
    after = config.suggestion.after
  }

  /// Fitted from the person's judged weeks, oldest first, and whether Health's sleep comes late.
  public init(
    before: [BufferWeek], after: [BufferWeek], lateOnset: Bool, config: TollConfig = .defaults
  ) {
    self.init(config: config)
    if let target = Self.target(.before, weeks: before, lateOnset: lateOnset, config: config) {
      self.before = target
      fitted.insert(.before)
    }
    if let target = Self.target(.after, weeks: after, lateOnset: lateOnset, config: config) {
      self.after = target
      fitted.insert(.after)
    }
  }

  public subscript(side: Gap.Side) -> Int { side == .before ? before : after }

  /// One side's fitted target; nil with too few judged weeks, so the baseline stands.
  static func target(
    _ side: Gap.Side, weeks: [BufferWeek], lateOnset: Bool, config: TollConfig
  ) -> Int? {
    let rule = config.suggestion
    let bounds = rule.bounds(side)
    let baseline = min(
      max(side == .before ? rule.before : rule.after, bounds.lowerBound), bounds.upperBound)
    let step = config.limits(side).step
    let judged = weeks.suffix(rule.lookbackWeeks).filter { $0.minutes > 0 && $0.verdict != .hold }
    guard judged.count >= rule.minWeeks else { return nil }
    func clamped(_ minutes: Int) -> Int { min(max(minutes, bounds.lowerBound), bounds.upperBound) }

    var smooth: [Int: Int] = [:]
    var hard: [Int: Int] = [:]
    for week in judged {
      if week.verdict == .smooth {
        smooth[week.minutes, default: 0] += 1
      } else {
        hard[week.minutes, default: 0] += 1
      }
    }
    let levels = Set(judged.map(\.minutes))
    // The highest level smooth more often than hard; a hard week below it was a bad week, not the
    // person's edge.
    let comfortable = levels.filter { smooth[$0, default: 0] > hard[$0, default: 0] }.max()
    let tooMuch = levels.filter {
      hard[$0, default: 0] >= max(1, smooth[$0, default: 0]) && $0 > (comfortable ?? 0)
    }
    if let ceiling = tooMuch.min() {
      return clamped(min(max(comfortable ?? 0, ceiling - step), baseline))
    }
    // Past the baseline only before sleep, for someone at their top level with no pause in the
    // buffer for weeks, and whose Health sleep comes late: the one sign the research suggests,
    // still untested.
    let last = judged.suffix(rule.raiseSmoothWeeks)
    if side == .before, lateOnset, last.count == rule.raiseSmoothWeeks,
      let top = last.first?.minutes, top >= baseline,
      last.allSatisfy({ $0.verdict == .smooth && $0.pauses == 0 && $0.minutes == top })
    {
      return clamped(top + step)
    }
    return baseline
  }
}

/// One of the person's past weeks on one side, as the weekly rule judged it: the buffer most of its
/// nights had, and the verdict from its nights, pauses in that buffer and Screen Time (D76).
public struct BufferWeek: Equatable, Sendable {
  public var minutes: Int
  public var verdict: Gap.Verdict
  public var pauses: Int

  public init(minutes: Int, verdict: Gap.Verdict, pauses: Int) {
    self.minutes = minutes
    self.verdict = verdict
    self.pauses = pauses
  }
}
