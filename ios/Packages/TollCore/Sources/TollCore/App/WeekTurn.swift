import Foundation

/// The week's turn with Dusk closed (#127). The buffers are judged at the first reconcile on or
/// after Monday noon (D83). With only the night's own wakes, a week judged while Dusk stays closed
/// would wait for that night's lock, which DeviceActivity still starts at last week's time. So the
/// monitor also wakes just after noon every day: on Monday that wake judges the week, moves the
/// DeviceActivity schedule to the new lock and hands iOS the heads-ups at their new times. On the
/// other days it changes nothing. Daily, like every other schedule Dusk sets, rather than weekly:
/// a repeating schedule by hour and minute is the form already checked on device.
public enum WeekTurn {
  /// The daily interval that wakes the monitor: from just after noon, for the platform's minimum.
  public static func window(_ config: TollConfig = .defaults) -> TimeWindow {
    let start = ClockTime(hour: 12).adding(minutes: config.gap.turnDelayMinutes)
    return TimeWindow(start: start, end: start.adding(minutes: TimeWindow.minimumMinutes))
  }

  /// The turn to schedule: once set up, while either buffer is judged weekly. A fixed buffer is
  /// never judged, so with both fixed nothing needs the wake.
  public static func schedule(_ state: DuskState, config: TollConfig = .defaults) -> TimeWindow? {
    guard state.setupFinishedAt != nil,
      Gap.Side.allCases.contains(where: { state[$0].judged })
    else { return nil }
    return window(config)
  }

  /// The heads-ups to hand iOS after a wake on Monday that changed a buffer, at the lock's new
  /// time; nil when nothing changed today or the switch is off. Whether iOS allows notifications
  /// is the adapter's to check.
  public static func headsUps(
    _ state: DuskState, now: Date, calendar: Calendar, config: TollConfig = .defaults
  ) -> [HeadsUp]? {
    guard state.headsUp else { return nil }
    let week = UnlockSupply.week(containing: now, calendar: calendar, config: config)
    guard calendar.isDate(now, inSameDayAs: week),
      Gap.Side.allCases.contains(where: { state[$0].change?.week == week })
    else { return nil }
    return HeadsUp.schedule(
      state, screenTime: state.screenTimeAllowed != false, permission: .allowed, now: now,
      calendar: calendar, config: config)
  }
}

extension Gap {
  /// Whether Monday's rule will judge it: growing, unless a fixed setting is held for the night's
  /// end.
  var judged: Bool {
    switch pending {
    case .grows: true
    case .fixed: false
    case nil: mode == .grows
    }
  }
}
