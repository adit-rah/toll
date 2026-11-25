import Foundation

/// iOS's answer about notifications, as the app last read it. Only the heads-up uses it (D68).
public enum NotificationPermission: String, Codable, Hashable, Sendable {
  case notAsked, allowed, denied
}

/// The one notification Dusk sends (D68, #104): "Apps lock in 20 min", before a night that will
/// block. It comes before the lock, which starts the gap before bed (D76). Nothing else is ever
/// notified.
public struct HeadsUp: Hashable, Sendable {
  /// When it arrives: the lead before the night's start.
  public var at: Date
  public var start: Date
  public var end: Date
  public var title: String
  /// The night as moon start – end sun puts it, in words: "10:30 pm – 7:00 am".
  public var body: String

  /// The nights ahead whose heads-up is still to come, oldest first, as the app should schedule them
  /// now. None unless setup is done, the switch is on and iOS allows it; then `nights`.
  public static func schedule(
    _ state: DuskState, screenTime: Bool, permission: NotificationPermission, now: Date,
    calendar: Calendar, config: TollConfig = .defaults
  ) -> [HeadsUp] {
    guard state.headsUp, permission == .allowed else { return [] }
    return nights(state, screenTime: screenTime, now: now, calendar: calendar, config: config)
  }

  /// The heads-ups the night's block would get, whatever the switch and the permission say: Tonight's
  /// card shows the first one's time while it asks (#104).
  public static func nights(
    _ state: DuskState, screenTime: Bool, now: Date, calendar: Calendar,
    config: TollConfig = .defaults
  ) -> [HeadsUp] {
    guard state.setupFinishedAt != nil, var sleep = state.sleepBlock else { return [] }
    // A held edit (B-3) applies when tonight's night ends, so every night after it runs on its hours.
    let tonightEnds = state.runtime.active[sleep.id]
    if case .save(let draft) = state.pending[sleep.id] { sleep = draft }
    guard sleep.isOn else { return [] }
    // Every night after now uses the gap as it will be: a change held through tonight counts.
    return nights(
      sleep.schedule.locking(before: state.gap.upcoming, after: state.after.upcoming),
      trial: state.trial, screenTime: screenTime,
      now: now, after: tonightEnds,
      calendar: calendar, config: config)
  }

  /// The rule: the next `nightsAhead` nights of `schedule` that start after `after` (or now), each
  /// with its heads-up the lead before it. A night whose heads-up time has passed gets none rather
  /// than a late one. None while Screen Time is off, and none for a night after the free week
  /// unless it's bought (P-2), since nothing would block then.
  public static func nights(
    _ schedule: WeeklySchedule, trial: TrialState, screenTime: Bool, now: Date, after: Date? = nil,
    calendar: Calendar, config: TollConfig = .defaults
  ) -> [HeadsUp] {
    guard screenTime else { return [] }
    let lead = TimeInterval(config.headsUp.leadMinutes * 60)
    var result: [HeadsUp] = []
    var cursor = max(now, after ?? now)
    for _ in 0..<config.headsUp.nightsAhead {
      guard let start = schedule.nextStart(after: cursor, calendar: calendar),
        let night = schedule.occurrence(containing: start, calendar: calendar)
      else { break }
      cursor = start
      guard entitled(trial, at: start, schedule: schedule, calendar: calendar, config: config)
      else { break }
      let at = start.addingTimeInterval(-lead)
      guard at > now else { continue }
      result.append(
        HeadsUp(
          at: at, start: start, end: night.end,
          title: Copy.HeadsUp.title(minutes: config.headsUp.leadMinutes),
          body: Copy.HeadsUp.body(
            start: Copy.time(start, in: calendar), end: Copy.time(night.end, in: calendar))))
    }
    return result
  }

  /// Whether a night starting then will block: bought, or one of the free nights (P-2). Nights are
  /// counted by their ends, so a free night is one that starts before the free week's last end.
  static func entitled(
    _ trial: TrialState, at start: Date, schedule: WeeklySchedule, calendar: Calendar,
    config: TollConfig
  ) -> Bool {
    if trial.purchased { return true }
    guard let since = trial.start else { return trial.entitled }
    return Trial.night(
      since: since, now: start, sleep: schedule, calendar: calendar, config: config)
      != nil
  }
}
