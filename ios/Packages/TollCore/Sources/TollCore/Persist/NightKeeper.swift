import Foundation

/// Night records are made from the transition log, which the app trims. Recording always comes
/// first, so a trim can't take a night before it's recorded (#140), and the monitor records each
/// night at its sweep, so a night doesn't wait for Dusk to be opened.
public struct NightKeeper: Sendable {
  public var transitions: TransitionLog
  public var nights: NightLog

  /// The monitor reads at most this much of each log: the extension has about 6 MB in all.
  static let logTailBytes = 64 * 1024
  static let nightsTailBytes = 16 * 1024
  /// The monitor records the nights that ended this recently; older ones are the app's.
  static let recentHours: TimeInterval = 36

  public init(transitions: TransitionLog = TransitionLog(), nights: NightLog = NightLog()) {
    self.transitions = transitions
    self.nights = nights
  }

  /// The app, on opening: every ended night since setup, from the whole log, then the trim, only
  /// if every night went in. Nil when one didn't: the log keeps it for the next try.
  @discardableResult
  public func keep(
    _ state: DuskState, model: ModelStamp, now: Date, calendar: Calendar,
    config: TollConfig = .defaults
  ) -> Int? {
    guard let sleep = state.sleepBlock else { return 0 }
    let ended = NightFacts.ended(
      log: transitions.read(limit: .max), sleep: sleep, gap: state.gap, after: state.after,
      since: state.setupFinishedAt,
      now: now, calendar: calendar, regret: TimeInterval(config.door.regretSeconds))
    guard let added = nights.record(ended, calendar: calendar, model: model, by: .app) else {
      return nil
    }
    transitions.trim()
    return added
  }

  /// The monitor, at a sweep: the nights that ended in the last day and a half, from the end of the
  /// log, each only if the lines read reach back to its noon, so no night is recorded from half its
  /// lines. Anything it can't do, the app does on opening.
  @discardableResult
  public func keepRecent(
    _ state: DuskState, model: ModelStamp, now: Date, calendar: Calendar,
    config: TollConfig = .defaults
  ) -> Int? {
    guard let sleep = state.sleepBlock, let setup = state.setupFinishedAt else { return 0 }
    let log = transitions.tail(bytes: Self.logTailBytes)
    let reach = log.whole ? nil : log.lines.map(\.at).min()
    let since = max(setup, now.addingTimeInterval(-Self.recentHours * 3600))
    let ended = NightFacts.ended(
      log: log.lines, sleep: sleep, gap: state.gap, after: state.after, since: since, now: now,
      calendar: calendar,
      regret: TimeInterval(config.door.regretSeconds)
    ).filter { night in
      guard let reach else { return true }
      let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: night.night)
      return noon.map { reach <= $0 } ?? false
    }
    guard !ended.isEmpty else { return 0 }
    let known = CoordinatedFile.tail(nights.url, bytes: Self.nightsTailBytes).lines
    return nights.record(ended, calendar: calendar, model: model, by: .monitor, known: known)
  }
}
