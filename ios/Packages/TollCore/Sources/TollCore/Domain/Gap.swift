import Foundation

/// A buffer around the person's sleep (D76, #144). The night's block stores sleep, bed (when they
/// fall asleep) to wake; the lock adds the buffer before (`DuskState.gap`) and the one after
/// (`DuskState.after`). Growing, a buffer follows the weekly rule (`judge`, as
/// `datascience/sim/gap_rule.py` simulated it) toward its own target; fixed, it stays where the
/// person put it.
public struct Gap: Codable, Hashable, Sendable {
  public enum Mode: String, Codable, Hashable, Sendable {
    case grows, fixed
  }

  /// Which side of sleep a buffer is on.
  public enum Side: String, Hashable, Sendable, CaseIterable {
    /// Apps lock this long before sleep.
    case before
    /// Apps stay locked this long after waking.
    case after
  }

  /// A side's numbers from `TollConfig`: where a new one starts, its step, the target it grows
  /// toward unless the person or the suggestion chose another, and what a person may choose.
  public struct Limits: Equatable, Sendable {
    public var start: Int
    public var step: Int
    public var target: Int
    public var manualMax: Int
    public var manualStep: Int
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

    public init(week: Date, from: Int, to: Int) {
      self.week = week
      self.from = from
      self.to = to
    }

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
  /// Growing never takes it past this (#144): the suggestion's, or the person's. D76's 60 for a
  /// gap from before it.
  public var target = TollConfig.defaults.gap.cap
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
    growing(from: config.gap.start, to: config.gap.cap)
  }

  /// A buffer that starts at `start` and grows toward `target` (#144).
  public static func growing(from start: Int, to target: Int) -> Gap {
    var gap = Gap()
    gap.minutes = min(max(start, 0), max(target, 0))
    gap.target = max(target, 0)
    gap.mode = .grows
    return gap
  }

  /// No buffer: what a night without one has, and the after side before it was offered (#144).
  public static func none(target: Int) -> Gap {
    var gap = Gap()
    gap.target = target
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

  /// The next number the weekly rule would grow it to; nil when fixed or at its target.
  public func next(_ step: Int) -> Int? {
    guard mode == .grows, minutes < target else { return nil }
    return min(minutes + step, target)
  }

  public func next(_ config: TollConfig) -> Int? { next(config.gap.step) }

  /// A setting held inside its bounds: growing, at most its target; fixed, 0 to the manual most.
  public static func clamped(_ setting: Setting, _ config: TollConfig) -> Setting {
    clamped(setting, target: config.gap.cap, limits: config.limits(.before))
  }

  public static func clamped(_ setting: Setting, target: Int, limits: Limits) -> Setting {
    switch setting {
    case .grows(let minutes): .grows(min(max(minutes, 0), target))
    case .fixed(let minutes): .fixed(min(max(minutes, 0), limits.manualMax))
    }
  }

  /// A target a person or the suggestion chose, inside what a person may choose.
  public static func clamped(target: Int, limits: Limits) -> Int {
    min(max(target, 0), limits.manualMax)
  }

  /// Puts a setting in force from the next night to start, keyed by today. A gap that starts
  /// growing starts the rule afresh.
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
}
