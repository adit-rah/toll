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

  /// The morning the free nights end: the `trial.nights`th night end after the start (P-2, D78).
  public static func lastEnd(
    since start: Date, sleep: WeeklySchedule, calendar: Calendar, config: TollConfig
  ) -> Date? {
    guard let horizon = horizon(from: start, config: config, calendar: calendar) else { return nil }
    let ends = sleep.ends(after: start, through: horizon, calendar: calendar)
    return ends.count >= config.trial.nights ? ends[config.trial.nights - 1] : nil
  }

  /// What setup can promise (#46). The trial's start survives a reinstall in the Keychain and follows
  /// the Apple ID (P-4, D78), so a phone that used its free nights isn't offered more.
  public enum Offer: Equatable, Sendable {
    /// No trial yet: it starts when setup ends.
    case fresh(endsAt: Date?)
    /// Started on this phone before and still running.
    case running(endsAt: Date)
    /// Used on this phone; it ended that morning.
    case used(endedAt: Date)
    case purchased
  }

  public static func offer(
    start: Date?, purchased: Bool, now: Date, sleep: WeeklySchedule, calendar: Calendar,
    config: TollConfig
  ) -> Offer {
    if purchased { return .purchased }
    guard let start else {
      return .fresh(endsAt: lastEnd(since: now, sleep: sleep, calendar: calendar, config: config))
    }
    guard let end = lastEnd(since: start, sleep: sleep, calendar: calendar, config: config) else {
      return .fresh(endsAt: nil)
    }
    return end <= now ? .used(endedAt: end) : .running(endsAt: end)
  }

  /// The free nights as This week keys them (the day each starts, noon to noon): the first
  /// `trial.nights` occurrences to end after the start, ended or not.
  static func nightKeys(
    since start: Date, sleep: WeeklySchedule?, calendar: Calendar, config: TollConfig
  ) -> [Date] {
    guard let sleep, let horizon = horizon(from: start, config: config, calendar: calendar) else {
      return []
    }
    return sleep.ends(after: start, through: horizon, calendar: calendar)
      .prefix(config.trial.nights)
      .compactMap { sleep.occurrence(containing: $0.addingTimeInterval(-1), calendar: calendar) }
      .map { calendar.startOfDay(for: $0.start.addingTimeInterval(-12 * 3600)) }
  }

  /// Far enough ahead to hold every free night of a Sleep block that runs one night a week.
  private static func horizon(from start: Date, config: TollConfig, calendar: Calendar) -> Date? {
    calendar.date(byAdding: .day, value: 7 * (config.trial.nights + 1), to: start)
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
