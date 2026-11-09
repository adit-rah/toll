#if os(iOS)
  import DeviceActivity
  import Foundation
  import OSLog
  import TollCore

  extension DeviceActivityName {
    public static let checkin = Self("checkin")
  }

  extension DeviceActivityEvent.Name {
    public static let sessionThreshold = Self("threshold")
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

    /// A one-off interval of `gate.sessionWindowMinutes` with a usage threshold of the chosen minutes (G-6).
    public func start(session: ActiveSession, tokens: TokenRegistry.Tokens, calendar: Calendar)
      throws
    {
      let parts: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
      let schedule = DeviceActivitySchedule(
        intervalStart: calendar.dateComponents(parts, from: session.startedAt),
        intervalEnd: calendar.dateComponents(parts, from: session.expiresAt),
        repeats: false)
      let event = DeviceActivityEvent(
        applications: tokens.applications, categories: tokens.categories,
        webDomains: tokens.webDomains,
        threshold: DateComponents(minute: session.minutes))
      try DeviceActivityCenter().startMonitoring(
        DeviceActivityName(session.activityName), during: schedule,
        events: [.sessionThreshold: event])
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
