import Foundation

/// A night as the night log keeps it (D62): its key, whether the block ran, and what Your sleep
/// counts over long ranges. The transition log holds about ten nights, so anything counted over more
/// reads these.
public struct PastNight: Equatable, Sendable {
  public var night: Date
  public var ran: Bool
  public var start: Date?
  public var end: Date?
  /// Nil in records written before the record kept it; the block's first-on to last-off stands in.
  public var locked: TimeInterval?
  /// When each "Never mind" tap was; nil in records written before the record kept them.
  public var taps: [Date]?

  public init(
    night: Date, ran: Bool, start: Date? = nil, end: Date? = nil, locked: TimeInterval? = nil,
    taps: [Date]? = nil
  ) {
    self.night = night
    self.ran = ran
    self.start = start
    self.end = end
    self.locked = locked
    self.taps = taps
  }

  init(_ facts: NightFacts) {
    self.init(
      night: facts.night, ran: facts.ran, start: facts.blockStart,
      end: facts.ran ? facts.blockEnd ?? facts.plannedEnd : nil, locked: facts.locked,
      taps: facts.taps)
  }

  /// How long the block kept the night's apps locked.
  public var lockedTime: TimeInterval {
    guard ran else { return 0 }
    if let locked { return locked }
    guard let start, let end else { return 0 }
    return max(0, end.timeIntervalSince(start))
  }

  /// Every ended night, oldest first: the night log's records, and the transition log's nights not
  /// recorded yet (the app records on foreground). A record wins over the log, which may have trimmed
  /// the start of its oldest night; the log fills in taps an older record didn't keep.
  public static func merged(
    history: [PastNight], state: DuskState, log: [Transition], now: Date, calendar: Calendar,
    regret: TimeInterval = 120
  ) -> [PastNight] {
    var byNight = Dictionary(history.map { ($0.night, $0) }, uniquingKeysWith: { first, _ in first })
    let lines = log.sorted { $0.at < $1.at }
    if let sleep = state.sleepBlock, let setup = state.setupFinishedAt {
      // Nights before the log's first line would all read as not run; they're in the history.
      let since = max(setup, lines.first.map { $0.at.addingTimeInterval(-86_400) } ?? setup)
      for facts in NightFacts.ended(
        log: lines, sleep: sleep, since: since, now: now, calendar: calendar, regret: regret)
      {
        guard var recorded = byNight[facts.night], recorded.ran || !facts.ran else {
          byNight[facts.night] = PastNight(facts)
          continue
        }
        if recorded.taps == nil, recorded.ran == facts.ran { recorded.taps = facts.taps }
        byNight[facts.night] = recorded
      }
    }
    return byNight.values.sorted { $0.night < $1.night }
  }

  /// Settings' "Last night": the latest night the block ran, with its day (the audit: a bare
  /// "10:30 pm – 7:00 am" could be Study's).
  public static func latest(
    history: [PastNight], state: DuskState, log: [Transition], now: Date, calendar: Calendar
  ) -> PastNight? {
    merged(history: history, state: state, log: log, now: now, calendar: calendar)
      .last { $0.ran && $0.start != nil }
  }
}
