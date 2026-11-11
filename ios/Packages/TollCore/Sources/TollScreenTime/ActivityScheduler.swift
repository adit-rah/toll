#if os(iOS)
  @preconcurrency import DeviceActivity
  import Foundation
  import OSLog
  import TollCore

  extension DeviceActivityName {
    public static var checkin: Self { Self("checkin") }
  }

  /// DeviceActivity monitoring for block windows, sessions and the daily check-in (spec §6, §11.1).
  /// Activities only wake the monitor; what is shielded is always decided by `ShieldPlan`.
  public struct ActivityScheduler: Sendable {
    private let log = Logger(subsystem: "com.advan.toll", category: "activity")

    public init() {}

    /// One repeating activity per scheduled block; always-on blocks need none. Activities for blocks that
    /// no longer exist are stopped.
    public func schedule(blocks: [BlockDefinition]) {
      let center = DeviceActivityCenter()
      let wanted = blocks.filter { $0.schedule.kind != .always }
      let wantedNames = Set(wanted.map { DeviceActivityName($0.activityName) })
      let stale = center.activities.filter {
        $0.rawValue.hasPrefix("block.") && !wantedNames.contains($0)
      }
      if !stale.isEmpty { center.stopMonitoring(stale) }
      for block in wanted {
        let schedule = DeviceActivitySchedule(
          intervalStart: DateComponents(
            hour: block.schedule.start.hour, minute: block.schedule.start.minute),
          intervalEnd: DateComponents(
            hour: block.schedule.end.hour, minute: block.schedule.end.minute),
          repeats: true)
        do {
          try center.startMonitoring(DeviceActivityName(block.activityName), during: schedule)
        } catch {
          log.error("block schedule failed: \(error.localizedDescription, privacy: .public)")
        }
      }
    }

    /// Wakes the monitor when the session's time is up (G-6). A session shorter than the platform's
    /// minimum interval rides a longer one and ends on its end warning (`SessionInterval`).
    public func start(session: ActiveSession, calendar: Calendar) throws {
      let interval = SessionInterval(session: session)
      let parts: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
      let schedule = DeviceActivitySchedule(
        intervalStart: calendar.dateComponents(parts, from: interval.start),
        intervalEnd: calendar.dateComponents(parts, from: interval.end),
        repeats: false,
        warningTime: interval.warningMinutes.map { DateComponents(minute: $0) })
      try DeviceActivityCenter().startMonitoring(
        DeviceActivityName(session.activityName), during: schedule)
    }

    public func stop(sessions: [ActiveSession]) {
      DeviceActivityCenter().stopMonitoring(sessions.map { DeviceActivityName($0.activityName) })
    }

    /// The daily check-in (N-9): a full-day repeating interval whose start writes a `checkin` line.
    public func scheduleCheckin() {
      let schedule = DeviceActivitySchedule(
        intervalStart: DateComponents(hour: 0, minute: 0),
        intervalEnd: DateComponents(hour: 23, minute: 59),
        repeats: true)
      do {
        try DeviceActivityCenter().startMonitoring(.checkin, during: schedule)
      } catch {
        log.error("checkin schedule failed: \(error.localizedDescription, privacy: .public)")
      }
    }

    public func stopAll() {
      DeviceActivityCenter().stopMonitoring()
    }
  }
#endif
