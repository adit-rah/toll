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

    /// Off: a start of 0 keeps that side fixed at none rather than growing from nothing.
    public var off: Bool { start == 0 }

    /// What it becomes in the state: growing from its start, or none.
    var setting: Gap.Setting { off ? .fixed(0) : .grows(start) }
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
}

extension Fit {
  /// What a new person is offered: the recommended baseline (`TollConfig.suggestion`), each side
  /// growing from its start. Health fits the hours, not these.
  public static func suggested(
    sleep: WeeklySchedule?, health: Bool, config: TollConfig = .defaults
  ) -> Fit {
    let baseline = BufferSuggestion(config: config)
    return Fit(
      sleep: sleep,
      before: Buffer(start: min(config.gap.start, baseline.before), target: baseline.before),
      after: Buffer(start: min(config.after.start, baseline.after), target: baseline.after),
      health: health)
  }

  /// Someone already using Dusk (the one-time flow): their night as it is and the same baseline
  /// as a new person, keeping their gap where it already starts at the baseline's start or more.
  public static func existing(_ state: DuskState, config: TollConfig = .defaults) -> Fit {
    var fit = suggested(sleep: state.sleepBlock?.schedule, health: state.health, config: config)
    let gap = state.gap.upcoming
    if gap >= fit.before.start {
      fit.before = Buffer(start: gap, target: max(fit.before.target, gap))
    }
    return fit
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
        side, fit[side].setting, target: fit[side].target, &state, now: now,
        calendar: calendar, config: config)
    }
    state.health = fit.health
    return nil
  }

  /// A new install's buffers, before the first night: in force at once, growing from the start,
  /// or none where the start is 0.
  static func install(_ fit: Fit, config: TollConfig) -> (before: Gap, after: Gap) {
    func gap(_ side: Gap.Side) -> Gap {
      let target = Gap.clamped(target: fit[side].target, limits: config.limits(side))
      return fit[side].off ? .none(target: target) : .growing(from: fit[side].start, to: target)
    }
    return (gap(.before), gap(.after))
  }
}
