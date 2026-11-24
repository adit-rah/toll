import Foundation

/// The gap before bed (D76): the night's block locks this many minutes before bed, and wake never
/// moves. Growing, it follows the weekly rule (`judge`, as `datascience/sim/gap_rule.py` simulated
/// it); fixed, it stays where the person put it. The code calls the stored night start bed.
public struct Gap: Codable, Hashable, Sendable {
  public enum Mode: String, Codable, Hashable, Sendable {
    case grows, fixed
  }

  /// What the person chose in Settings, or on a Tonight card.
  public enum Setting: Codable, Hashable, Sendable {
    case grows(Int)
    case fixed(Int)
  }

  /// A change the weekly rule made, for Monday's card.
  public struct Change: Codable, Hashable, Sendable {
    /// The week it starts (the pauses' week key, D70).
    public var week: Date
    public var from: Int
    public var to: Int
    /// The card was answered: kept or put away.
    public var seen = false

    public var grew: Bool { to > from }
  }

  /// One week's facts as the weekly rule reads them.
  public struct Tally: Codable, Hashable, Sendable {
    /// The pauses' week key (D70); nil until the first reconcile after setup.
    public var week: Date?
    /// Night keys the lock ran.
    public var nights: Set<Date> = []
    public var pausesInGap = 0
    public var screenTimeOff = false

    public init(week: Date? = nil) {
      self.week = week
    }
  }

  /// From which night a gap was in force, so a night record carries its own.
  public struct Entry: Codable, Hashable, Sendable {
    public var night: Date
    public var minutes: Int
  }

  /// In force tonight.
  public var minutes = 0
  public var mode = Mode.fixed
  /// A change made while the night's block is on; it applies when that night ends (B-3).
  public var pending: Setting?
  /// Smooth weeks in a row since the last growth or ease.
  public var streak = 0
  /// Eased since it last grew: two smooth weeks in a row before it grows again.
  public var eased = false
  /// No growth at a Monday on or before this week key (Screen Time was switched off).
  public var frozenThrough: Date?
  public var tally = Tally()
  public var change: Change?
  /// An install from before D76 is offered the gap once, on Tonight.
  public var offered = false
  /// The latest few changes in force, oldest first.
  public var history: [Entry] = []

  public init() {}

  /// A new install's gap: it starts at `start` and grows.
  public static func newInstall(_ config: TollConfig = .defaults) -> Gap {
    var gap = Gap()
    gap.minutes = config.gap.start
    gap.mode = .grows
    return gap
  }

  /// An install from before D76 keeps its night as it is, and sees one card offering the gap.
  public static var existing: Gap {
    var gap = Gap()
    gap.offered = true
    return gap
  }

  public var setting: Setting { mode == .grows ? .grows(minutes) : .fixed(minutes) }

  /// The gap the next night will use: a held change counts.
  public var upcoming: Int {
    switch pending {
    case .grows(let minutes), .fixed(let minutes): minutes
    case nil: minutes
    }
  }

  /// The gap a night used, from its key.
  public func minutes(forNight night: Date) -> Int {
    guard !history.isEmpty else { return minutes }
    return history.last { $0.night <= night }?.minutes ?? 0
  }

  /// The next number the weekly rule would grow it to; nil when fixed or at the cap.
  public func next(_ config: TollConfig) -> Int? {
    guard mode == .grows, minutes < config.gap.cap else { return nil }
    return min(minutes + config.gap.step, config.gap.cap)
  }

  /// A setting held inside its bounds: growing, at most the cap; fixed, 0 to the manual most.
  public static func clamped(_ setting: Setting, _ config: TollConfig) -> Setting {
    switch setting {
    case .grows(let minutes): .grows(min(max(minutes, 0), config.gap.cap))
    case .fixed(let minutes): .fixed(min(max(minutes, 0), config.gap.manualMax))
    }
  }

  /// Puts a setting in force from the night after `now`'s key. A new growing gap starts the rule
  /// afresh.
  mutating func put(_ setting: Setting, now: Date, calendar: Calendar) {
    let old = (minutes, mode)
    switch setting {
    case .grows(let value): (minutes, mode) = (value, .grows)
    case .fixed(let value): (minutes, mode) = (value, .fixed)
    }
    if mode == .grows, old.1 != .grows {
      streak = 0
      eased = false
    }
    pending = nil
    guard minutes != old.0 else { return }
    // The gap every night before the first change had.
    if history.isEmpty {
      history.append(Entry(night: Date(timeIntervalSince1970: 0), minutes: old.0))
    }
    let night = calendar.startOfDay(for: now)
    history.removeAll { $0.night >= night }
    history.append(Entry(night: night, minutes: minutes))
    if history.count > 12 { history.removeFirst(history.count - 12) }
  }

  // MARK: The weekly rule

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

  /// Monday `week`'s judgement of the week before it (D76): smooth grows by a step, up to the cap,
  /// unless frozen or still owed smooth weeks after an ease; hard or Screen Time off eases by a
  /// step; Screen Time off also freezes growth for the next Mondays. Anything else holds. Returns
  /// the new number.
  mutating func judge(_ tally: Tally, week: Date, calendar: Calendar, config: TollConfig) -> Int {
    guard mode == .grows else { return minutes }
    let verdict = Self.verdict(tally, config)
    let ease = verdict == .hard || verdict == .screenTimeOff
    if verdict == .screenTimeOff {
      frozenThrough = calendar.date(
        byAdding: .day, value: 7 * config.gap.offFreezeWeeks, to: week)
    }
    streak = verdict == .smooth ? streak + 1 : 0
    let needed = eased ? config.gap.smoothAfterEase : 1
    let frozen = frozenThrough.map { week <= $0 } ?? false
    let grow = verdict == .smooth && streak >= needed && !frozen && minutes < config.gap.cap
    var next = minutes
    if grow { next += config.gap.step }
    if ease { next -= config.gap.step }
    if grow { streak = 0 }
    eased = (eased && !grow) || ease
    return min(max(next, 0), config.gap.cap)
  }
}

extension WeeklySchedule {
  /// The lock's hours: each rule's start moved `minutes` earlier, wake unchanged (D76). A start
  /// moved back past midnight starts the day before. Never longer than a day can hold.
  public func locking(_ minutes: Int) -> WeeklySchedule {
    guard minutes > 0 else { return self }
    return WeeklySchedule(
      rules: rules.map { rule in
        let room = 1440 - TimeWindow.minimumMinutes - rule.window.minutes
        let lead = max(0, min(minutes, room))
        let start = rule.window.start.adding(minutes: -lead)
        let days =
          start.minuteOfDay > rule.window.start.minuteOfDay
          ? Set(rule.days.map(\.previous)) : rule.days
        return Rule(days: days, window: TimeWindow(start: start, end: rule.window.end))
      })
  }
}

extension Weekday {
  var previous: Weekday { Weekday(rawValue: (rawValue + 5) % 7 + 1) ?? .sunday }
}
