#if os(iOS)
  @preconcurrency import DeviceActivity
  import Foundation
  import OSLog
  import TollCore

  /// SchedulePort on DeviceActivity: a repeating schedule per window with a sweep after it, and the
  /// door's interval. They only wake the monitor; the engine decides (docs/architecture.md).
  public struct ScheduleAdapter: SchedulePort {
    /// The sweep starts a minute after a window ends and lasts the platform's minimum (D14).
    static let sweepDelayMinutes = 1
    private let logger = Logger(subsystem: "com.advan.toll", category: "schedule")

    public init() {}

    public func monitor(windows: [TimeWindow]) throws {
      let center = DeviceActivityCenter()
      let wanted = Set(windows.flatMap { [Activity.window($0).name, Activity.sweep($0).name] })
      let stale = center.activities.filter { name in
        switch Activity(name) {
        case .window, .sweep: !wanted.contains(name)
        case .turn, .door: false
        case .unknown: true
        }
      }
      if !stale.isEmpty { center.stopMonitoring(stale) }
      for window in windows where window.isValid {
        try center.startMonitoring(
          Activity.window(window).name,
          during: DeviceActivitySchedule(
            intervalStart: window.start.components, intervalEnd: window.end.components,
            repeats: true))
        let sweep = window.end.adding(minutes: Self.sweepDelayMinutes)
        try center.startMonitoring(
          Activity.sweep(window).name,
          during: DeviceActivitySchedule(
            intervalStart: sweep.components,
            intervalEnd: sweep.adding(minutes: TimeWindow.minimumMinutes).components, repeats: true)
        )
      }
    }

    /// From the end of the wait, the platform's minimum interval (15 minutes), warning at the pause's
    /// 10 (D67): the warning is the timer that runs with the app closed (D31). Its start lifts the
    /// shields; the warning puts them back.
    public func startDoor(_ door: Door, config: TollConfig) throws {
      let calendar = Calendar.current
      let parts: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
      let interval = DoorRules.intervalMinutes(config)
      let end = door.waitEndsAt.addingTimeInterval(TimeInterval(interval * 60))
      let schedule = DeviceActivitySchedule(
        intervalStart: calendar.dateComponents(parts, from: door.waitEndsAt),
        intervalEnd: calendar.dateComponents(parts, from: end), repeats: false,
        warningTime: DateComponents(minute: interval - config.door.minutes))
      do {
        try DeviceActivityCenter().startMonitoring(Activity.door.name, during: schedule)
      } catch {
        logger.error("door schedule failed: \(error.localizedDescription, privacy: .public)")
        throw error
      }
    }

    public func stopDoor() {
      DeviceActivityCenter().stopMonitoring([Activity.door.name])
    }

    /// Asked on every saved reconcile, so it starts the wake only when DeviceActivity doesn't have
    /// it, and stops any other turn. A failure is tried again at the next reconcile.
    public func monitor(turn: TimeWindow?) {
      let center = DeviceActivityCenter()
      let wanted = turn.map { Activity.turn($0).name }
      let turns = center.activities.filter {
        if case .turn = Activity($0) { true } else { false }
      }
      let stale = turns.filter { $0 != wanted }
      if !stale.isEmpty { center.stopMonitoring(stale) }
      guard let turn, let wanted, !turns.contains(wanted) else { return }
      do {
        try center.startMonitoring(
          wanted,
          during: DeviceActivitySchedule(
            intervalStart: turn.start.components, intervalEnd: turn.end.components, repeats: true))
      } catch {
        logger.error("turn schedule failed: \(error.localizedDescription, privacy: .public)")
      }
    }
  }

  extension Coordinator {
    /// The coordinator every host uses: the App Group file, the shield, DeviceActivity and the log.
    public static func live(config: TollConfig = .defaults) -> Coordinator {
      Coordinator(
        store: DuskStore(), shield: ShieldAdapter(), schedule: ScheduleAdapter(),
        log: TransitionLog(),
        config: config)
    }

    /// Reconcile now, with the system clock: what a host does when it wakes (B-5).
    @discardableResult
    public func wake(_ cause: ReconcileCause, _ commands: [Command] = []) -> Outcome {
      run(cause, commands, clock: SystemClock())
    }

    /// The monitor's wake at the week's turn (#127): on Monday it judges the buffers, and when one
    /// changed, that night's heads-up moves to the new lock though Dusk stays closed.
    public func turn() {
      let outcome = wake(.weekTurn)
      guard outcome.access == .saved,
        let plan = WeekTurn.headsUps(
          outcome.state, now: Date(), calendar: .current, config: config)
      else { return }
      HeadsUpNotifications.replaceIfAllowed(plan)
    }
  }

  extension Coordinator.Outcome {
    /// The monitor's sweep: a night that just ended goes into the night log now, not when Dusk is
    /// next opened (#140). Never from a state it couldn't read; stamped with the artifact this
    /// build carries.
    public func recordNight() {
      guard access != nil else { return }
      NightKeeper().keepRecent(
        state, model: .fixed(BundledModel.version), now: Date(), calendar: .current)
    }
  }
#endif
