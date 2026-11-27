import Foundation

extension Gap {
  public enum Verdict: Equatable, Sendable {
    case smooth, hard, screenTimeOff, hold
  }

  public static func verdict(_ tally: Tally, _ config: TollConfig) -> Verdict {
    if tally.screenTimeOff { return .screenTimeOff }
    if tally.pausesInGap >= config.gap.hardPauses { return .hard }
    if tally.nights.count >= config.gap.smoothMinNights,
      tally.pausesInGap <= config.gap.smoothMaxPauses
    {
      return .smooth
    }
    return .hold
  }

  /// Monday `week`'s judgement of the week before it (D76): smooth grows by a step, up to the
  /// buffer's target, unless frozen or still owed smooth weeks after an ease; hard or Screen Time
  /// off eases by a step; Screen Time off also freezes growth for the next Mondays. Anything else
  /// holds. Returns the new number. Both sides use the same rule, each with its own step (#144).
  mutating func judge(
    _ tally: Tally, week: Date, calendar: Calendar, config: TollConfig, step: Int? = nil
  ) -> Int {
    guard mode == .grows else { return minutes }
    let step = step ?? config.gap.step
    let verdict = Self.verdict(tally, config)
    let ease = verdict == .hard || verdict == .screenTimeOff
    if verdict == .screenTimeOff {
      frozenThrough = calendar.date(
        byAdding: .day, value: 7 * config.gap.offFreezeWeeks, to: week)
    }
    streak = verdict == .smooth ? streak + 1 : 0
    let needed = eased ? config.gap.smoothAfterEase : 1
    let frozen = frozenThrough.map { week <= $0 } ?? false
    let grow = verdict == .smooth && streak >= needed && !frozen && minutes < target
    var next = minutes
    if grow { next = min(next + step, target) }
    if ease { next -= step }
    if grow { streak = 0 }
    eased = (eased && !grow) || ease
    return max(next, 0)
  }
}

extension WeeklySchedule {
  /// The lock's hours: each rule's start moved `minutes` earlier, wake unchanged (D76). A start
  /// moved back past midnight starts the day before. Never longer than a day can hold.
  public func locking(_ minutes: Int) -> WeeklySchedule {
    locking(before: minutes, after: 0)
  }

  /// The lock's hours around sleep (#144): each rule's start moved `before` earlier and its end
  /// `after` later. A start moved back past midnight starts the day before. Never longer than a day
  /// can hold: the before side keeps its room first.
  public func locking(before: Int, after: Int) -> WeeklySchedule {
    guard before > 0 || after > 0 else { return self }
    return WeeklySchedule(
      rules: rules.map { rule in
        let room = max(0, 1440 - TimeWindow.minimumMinutes - rule.window.minutes)
        let lead = max(0, min(before, room))
        let trail = max(0, min(after, room - lead))
        let start = rule.window.start.adding(minutes: -lead)
        let days =
          start.minuteOfDay > rule.window.start.minuteOfDay
          ? Set(rule.days.map(\.previous)) : rule.days
        return Rule(
          days: days,
          window: TimeWindow(start: start, end: rule.window.end.adding(minutes: trail)))
      })
  }
}

extension Weekday {
  var previous: Weekday { Weekday(rawValue: (rawValue + 5) % 7 + 1) ?? .sunday }
}
