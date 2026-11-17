#if os(iOS)
  import Foundation
  import OSLog
  import TollCore

  /// B-5: the app and every extension run this whenever they wake. It reads the shared state, decides
  /// with `Reconcile`, applies the shield, writes the log line and keeps the schedule in step.
  public struct Reconciler: Sendable {
    public let store: SleepStore
    public let log: TransitionLog
    public let config: TollConfig
    private let logger = Logger(subsystem: "com.advan.toll", category: "reconcile")

    public init(
      store: SleepStore = SleepStore(), log: TransitionLog = TransitionLog(),
      config: TollConfig = .defaults
    ) {
      self.store = store
      self.log = log
      self.config = config
    }

    /// `change` runs first, inside the same write, so an edit or a presence update and the decision
    /// that follows from it can never be split by another process.
    @discardableResult
    public func run(
      _ cause: ReconcileCause, clock: any TollClock = SystemClock(),
      change: (inout SleepState) -> Void = { _ in }
    ) -> SleepState {
      var calendar = Calendar.current
      calendar.timeZone = clock.timeZone
      var reschedule = false
      var doorBefore: Door?
      let (state, outcome) = store.update { state in
        doorBefore = state.door
        change(&state)
        let outcome = Reconcile.run(
          &state, wall: clock.now, monotonic: clock.monotonic, calendar: calendar, cause: cause,
          config: config)
        // Marked before the call: starting a schedule inside its interval wakes the monitor at once,
        // and that wake must not schedule again.
        if state.scheduledWindow != state.settings.window {
          state.scheduledWindow = state.settings.window
          reschedule = true
        }
        return (state, outcome)
      }
      SleepShield.apply(
        on: state.blockOn, keepOpen: state.settings.keepOpen,
        doorApp: state.door?.phase == .open ? state.door?.app : nil)
      if let line = outcome.transition { log.append(line) }
      if reschedule { schedule(state.settings.window) }
      syncDoor(before: doorBefore, after: state.door)
      logger.info(
        "reconcile cause=\(cause.rawValue, privacy: .public) on=\(state.blockOn) changed=\(outcome.transition?.changed ?? false)"
      )
      return state
    }

    private func syncDoor(before: Door?, after: Door?) {
      if before == nil, let door = after {
        do {
          try DoorSchedule.start(door, config: config)
        } catch {
          // The app's own timer and the next reconcile still open and close it by the stored times.
          logger.error("door schedule failed: \(error.localizedDescription, privacy: .public)")
        }
      } else if before != nil, after == nil {
        DoorSchedule.stop()
      }
    }

    private func schedule(_ window: SleepWindow?) {
      do {
        try WindowSchedule.set(window)
      } catch {
        logger.error("schedule failed: \(error.localizedDescription, privacy: .public)")
        // Forgotten, so the next wake tries again.
        store.update { $0.scheduledWindow = nil }
      }
    }
  }
#endif
