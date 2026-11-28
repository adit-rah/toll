import Foundation

/// Personal timing in the engine (D66, D99). The app draws the week's start with the sleep model
/// (`ask`, then `Command.hold`), on opening, for the next night that hasn't started; the engine
/// keeps it in force to the end of its week, and every process locks with it. A start is only ever
/// put in force or taken out between nights, never while the night's lock is on (B-3), so a night
/// runs and is recorded with one start.
public enum TimingRules {
  /// What the app asks the sleep model for: the night the start is for, what's known of it, the
  /// starts the person's buffers allow, the latest hold, and the generator to draw with.
  public struct Ask: Equatable, Sendable {
    /// The night's key, "yyyy-MM-dd".
    public var night: String
    public var weekend: Bool
    /// Offsets from the plan, in minutes; the plan's 0 is always among them.
    public var allowed: [Int]
    /// The latest hold drawn: the model keeps it while tonight is in its week and it's allowed.
    public var held: Timing.Hold?
    /// Nil before the first draw: the app seeds one.
    public var generator: UInt64?
  }

  /// The next night to start, by the lock in force: its key and when its lock starts. Nil while
  /// the night's lock is on, and without a night.
  static func next(_ state: DuskState, now: Date, calendar: Calendar) -> (key: Date, start: Date)? {
    guard let lock = state.lockSleep,
      lock.schedule.occurrence(containing: now, calendar: calendar) == nil,
      let start = lock.schedule.nextStart(after: now, calendar: calendar)
    else { return nil }
    return (nightKey(start, calendar), start)
  }

  /// Whether a hold may run on a night: personal timing is on, the night is in the hold's week and
  /// not before it, and tonight's buffer before sleep still allows its start.
  static func keeps(
    _ hold: Timing.Hold, night: String, _ state: DuskState, config: TollConfig
  ) -> Bool {
    guard state.timing.on, let week = Timing.week(night), Timing.week(hold.start) == week,
      hold.start <= night
    else { return false }
    return Timing.allowed(before: state.gap.minutes, config: config).contains(hold.offset)
  }

  /// Every reconcile, once the night's held changes have applied: a hold whose week has ended, or
  /// whose start the buffer no longer allows, or that the person switched off, gives the lock back
  /// to the plan from the next night. Returns whether the lock moved.
  static func advance(
    _ state: inout DuskState, now: Date, calendar: Calendar, config: TollConfig
  ) -> Bool {
    guard let hold = state.timing.inForce, let next = next(state, now: now, calendar: calendar)
    else { return false }
    let night = NightRecordLine.key(next.key, calendar: calendar)
    guard !keeps(hold, night: night, state, config: config) else { return false }
    state.timing.put(nil, from: next.key)
    return true
  }

  /// What to ask the sleep model, or nil when nothing is to be drawn: personal timing is off, the
  /// person hasn't chosen Health (D65: the model learns only from Health's sleep), the night's lock
  /// is on or too close, or tonight's start is already held.
  public static func ask(
    _ state: DuskState, now: Date, calendar: Calendar, config: TollConfig = .defaults
  ) -> Ask? {
    guard state.timing.on, state.health, state.setupFinishedAt != nil,
      let next = next(state, now: now, calendar: calendar),
      next.start.timeIntervalSince(now) >= TimeInterval(config.timing.chooseBeforeMinutes * 60)
    else { return nil }
    let night = NightRecordLine.key(next.key, calendar: calendar)
    if let hold = state.timing.inForce, keeps(hold, night: night, state, config: config) {
      return nil
    }
    let bed = next.start.addingTimeInterval(TimeInterval(state.lead * 60))
    return Ask(
      night: night, weekend: [6, 7].contains(calendar.component(.weekday, from: bed)),
      allowed: Timing.allowed(before: state.gap.minutes, config: config),
      held: state.timing.lastHold, generator: state.timing.generator.flatMap { UInt64($0) })
  }

  /// The model's answer (`Command.hold`): in force from the next night, with the generator as the
  /// draw left it. An answer to a question no longer asked (the night started, the buffer changed,
  /// a newer answer landed) changes nothing, the generator included, so the next ask draws the same.
  static func choose(
    _ hold: Timing.Hold, generator: UInt64, _ state: inout DuskState, now: Date,
    calendar: Calendar, config: TollConfig
  ) {
    guard let ask = ask(state, now: now, calendar: calendar, config: config),
      let next = next(state, now: now, calendar: calendar),
      keeps(hold, night: ask.night, state, config: config)
    else { return }
    state.timing.generator = String(generator)
    state.timing.put(hold, from: next.key)
  }
}
