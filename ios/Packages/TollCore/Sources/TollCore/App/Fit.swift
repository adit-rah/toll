import Foundation

/// Dusk fitted to the person's sleep (#144): their sleep, bed to wake, and a buffer each side that
/// starts gently and grows toward its target. Onboarding sends it with setup; the one-time flow and
/// Settings send it alone.
public struct Fit: Equatable, Sendable {
  public struct Buffer: Equatable, Sendable {
    /// Tonight's minutes.
    public var start: Int
    /// What the weekly rule grows it toward.
    public var target: Int

    public init(start: Int, target: Int) {
      self.start = start
      self.target = target
    }
  }

  /// Bed to wake, weekends apart when they differ; nil keeps the night's hours.
  public var sleep: WeeklySchedule?
  public var before: Buffer
  public var after: Buffer
  /// Read from Apple Health: the night log is corrected with its sleep.
  public var health: Bool

  public init(sleep: WeeklySchedule?, before: Buffer, after: Buffer, health: Bool) {
    self.sleep = sleep
    self.before = before
    self.after = after
    self.health = health
  }

  public subscript(side: Gap.Side) -> Buffer {
    get { side == .before ? before : after }
    set {
      switch side {
      case .before: before = newValue
      case .after: after = newValue
      }
    }
  }

  /// What a new person is offered: the suggestion's targets, and each side's gentle start.
  public static func suggested(
    sleep: WeeklySchedule?, _ suggestion: BufferSuggestion, health: Bool,
    config: TollConfig = .defaults
  ) -> Fit {
    Fit(
      sleep: sleep,
      before: Buffer(start: min(config.gap.start, suggestion.before), target: suggestion.before),
      after: Buffer(start: min(config.after.start, suggestion.after), target: suggestion.after),
      health: health)
  }

  /// Someone already using Dusk (the one-time flow): their night and their gap as they are, the
  /// suggestion's targets where theirs are lower, and the after side's gentle start.
  public static func existing(
    _ state: DuskState, _ suggestion: BufferSuggestion, config: TollConfig = .defaults
  ) -> Fit {
    let gap = state.gap
    return Fit(
      sleep: state.sleepBlock?.schedule,
      before: Buffer(start: gap.upcoming, target: max(gap.target, suggestion.before, gap.upcoming)),
      after: Buffer(start: min(config.after.start, suggestion.after), target: suggestion.after),
      health: state.health)
  }

  /// Fitted: the night's hours as chosen, and both buffers growing from their starts.
  static func apply(
    _ fit: Fit, to state: inout DuskState, now: Date, calendar: Calendar, config: TollConfig
  ) -> CommandError? {
    if let schedule = fit.sleep, var sleep = state.sleepBlock {
      if case .save(let held) = state.pending[sleep.id] { sleep = held }
      sleep.schedule = schedule
      if let error = Engine.apply(
        .saveBlock(sleep), to: &state, now: now, calendar: calendar, config: config)
      {
        return error
      }
    }
    for side in Gap.Side.allCases {
      GapRules.set(
        side, .grows(fit[side].start), target: fit[side].target, &state, now: now,
        calendar: calendar, config: config)
    }
    state.health = fit.health
    return nil
  }

  /// A new install's buffers, before the first night: in force at once, growing from the start.
  static func install(_ fit: Fit, config: TollConfig) -> (before: Gap, after: Gap) {
    let before = config.limits(.before)
    let after = config.limits(.after)
    return (
      .growing(
        from: fit.before.start, to: Gap.clamped(target: fit.before.target, limits: before)),
      .growing(from: fit.after.start, to: Gap.clamped(target: fit.after.target, limits: after))
    )
  }
}
