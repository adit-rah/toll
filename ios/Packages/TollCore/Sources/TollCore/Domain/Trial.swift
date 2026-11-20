import Foundation

/// P-2, P-3: the first nights after setup are free, home or not; after them only a purchase turns
/// blocks on. Nights are the Sleep block's occurrences, counted by their ends (spec §3).
public enum Trial {
  public static func nightsEnded(
    since start: Date, now: Date, sleep: WeeklySchedule?, calendar: Calendar
  ) -> Int {
    sleep?.ends(after: start, through: now, calendar: calendar).count ?? 0
  }

  /// The night that is free now or next, counting from 1; nil once the trial is over.
  public static func night(
    since start: Date, now: Date, sleep: WeeklySchedule?, calendar: Calendar, config: TollConfig
  ) -> Int? {
    let ended = nightsEnded(since: start, now: now, sleep: sleep, calendar: calendar)
    return ended < config.trial.nights ? ended + 1 : nil
  }

  /// The free nights as This week keys them (the day each starts, noon to noon): the first
  /// `trial.nights` occurrences to end after the start, ended or not.
  static func nightKeys(
    since start: Date, sleep: WeeklySchedule?, calendar: Calendar, config: TollConfig
  ) -> [Date] {
    guard let sleep, let horizon = calendar.date(byAdding: .day, value: 30, to: start) else {
      return []
    }
    return sleep.ends(after: start, through: horizon, calendar: calendar)
      .prefix(config.trial.nights)
      .compactMap { sleep.occurrence(containing: $0.addingTimeInterval(-1), calendar: calendar) }
      .map { calendar.startOfDay(for: $0.start.addingTimeInterval(-12 * 3600)) }
  }

  public static func isEntitled(
    _ state: DuskState, now: Date, calendar: Calendar, config: TollConfig
  ) -> Bool {
    if state.trial.purchased { return true }
    // Before setup there is no trial and nothing to block.
    guard let start = state.trial.start else { return true }
    return night(
      since: start, now: now, sleep: state.sleepBlock?.schedule, calendar: calendar, config: config)
      != nil
  }
}
