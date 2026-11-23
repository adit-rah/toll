import Foundation

/// The one path every change takes, in the app and in every extension (B-5): commands and reconcile
/// in a single write of the state, then each effect handed to its port.
public struct Coordinator: Sendable {
  public struct Outcome: Sendable {
    public var state: DuskState
    public var effects: Effects
    /// The first command that was refused, if any; the others still applied and reconcile still ran.
    public var error: CommandError?
  }

  let store: any StatePort
  let shield: any ShieldPort
  let schedule: any SchedulePort
  let log: any LogPort
  public let config: TollConfig

  public init(
    store: any StatePort, shield: any ShieldPort, schedule: any SchedulePort, log: any LogPort,
    config: TollConfig = .defaults
  ) {
    self.store = store
    self.shield = shield
    self.schedule = schedule
    self.log = log
    self.config = config
  }

  @discardableResult
  public func run(_ cause: ReconcileCause, _ commands: [Command] = [], clock: any TollClock)
    -> Outcome
  {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = clock.timeZone
    let now = clock.now
    let monotonic = clock.monotonic
    let config = config
    let outcome = store.update { state -> Outcome in
      var error: CommandError?
      for command in commands {
        if let refused = Engine.apply(
          command, to: &state, now: now, calendar: calendar, config: config), error == nil
        {
          error = refused
        }
      }
      let effects = Engine.reconcile(
        &state, wall: now, monotonic: monotonic, calendar: calendar, cause: cause, config: config)
      return Outcome(state: state, effects: effects, error: error)
    }
    perform(outcome.effects)
    return outcome
  }

  private func perform(_ effects: Effects) {
    shield.apply(effects.shield)
    if let line = effects.log { log.append(line) }
    if let windows = effects.windows {
      do {
        try schedule.monitor(windows: windows)
      } catch {
        // Forgotten, so the next wake tries again.
        store.update { $0.runtime.scheduledWindows = nil }
      }
    }
    switch effects.door {
    case .start(let door):
      // The app's own timer and the next reconcile still open and close it by the stored times.
      try? schedule.startDoor(door, config: config)
    case .stop:
      schedule.stopDoor()
    case nil:
      break
    }
  }
}
