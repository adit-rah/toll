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

/// The trial-ended screen's facts (spec §7), read from the transition log.
public struct TrialSummary: Equatable, Sendable {
  public var nightsBlocked: Int
  public var blockScreens: Int

  public init(nightsBlocked: Int, blockScreens: Int) {
    self.nightsBlocked = nightsBlocked
    self.blockScreens = blockScreens
  }

  /// Nights with the block on at home: distinct nights, keyed by the date twelve hours before, so one
  /// night's on, off and on again counts once. The block screen is counted by its button taps: the
  /// system draws it without telling the app (decisions D24).
  public init(log: [Transition], calendar: Calendar) {
    var nights = Set<DateComponents>()
    for line in log where line.blockOn && line.changed {
      let noonBefore = line.at.addingTimeInterval(-12 * 3600)
      nights.insert(calendar.dateComponents([.year, .month, .day], from: noonBefore))
    }
    nightsBlocked = nights.count
    blockScreens = log.filter { $0.cause == .blockScreen }.count
  }
}
