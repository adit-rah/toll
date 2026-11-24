import Foundation

/// The morning card on Tonight (D65, #103): last night from Dusk's own log, in place of the
/// "starts at" hero from the end of the night until noon. Exact facts about the person's own night,
/// and nothing to keep up. A night that was due and didn't run shows no card: a bad night is neutral
/// and forward-looking, so Tonight looks ahead instead.
public struct Morning: Equatable, Sendable {
  public enum Outcome: Equatable, Sendable {
    /// The block ran, at home or anywhere.
    case ran
    /// Away from home through the night, so nothing blocked.
    case away
    /// Screen Time was off for Dusk, so nothing could block (#60).
    case noScreenTime
  }

  /// A stretch of last night, as fractions of its planned hours.
  public struct Span: Equatable, Sendable {
    public var start: Double
    public var end: Double
  }

  public var outcome: Outcome
  /// When the block first came on and last went off; the planned hours when it didn't run.
  public var from: String
  public var to: String
  /// Where the block was on; the room between two of them is a gap (a pause, or a time away).
  public var ran: [Span]
  public var gaps: [Span]
  /// "You put it down 3 times": the "Never mind" taps while the night's block was on (D46). Nil at
  /// zero, since nothing new means nothing shown.
  public var putDown: String?
  /// The bar and its times in words, for VoiceOver.
  public var spoken: String
  /// What the bar and its times are (D75): "Apps locked last night" when it ran; "Last night"
  /// when it didn't, since the card's line says why.
  public var eyebrow: String

  /// Nil outside the morning, before setup, after the trial (the off hero speaks then), and
  /// when last night was due and simply didn't run.
  init?(
    state: DuskState, log: [Transition], now: Date, calendar: Calendar,
    config: TollConfig = .defaults
  ) {
    guard state.trial.entitled, let sleep = state.sleepBlock, let setup = state.setupFinishedAt,
      let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: now), now < noon
    else { return nil }
    let lines = log.sorted { $0.at < $1.at }
    // Only last night matters, so the search starts a day and a half back rather than at setup.
    guard
      let night = NightFacts.ended(
        log: lines, sleep: sleep, since: max(setup, now.addingTimeInterval(-36 * 3600)),
        now: now, calendar: calendar, regret: TimeInterval(config.door.regretSeconds)
      ).last,
      night.night == nightKey(now, calendar), !night.paused
    else { return nil }
    if night.ran {
      outcome = .ran
    } else if night.screenTimeOff {
      outcome = .noScreenTime
    } else if night.away {
      outcome = .away
    } else {
      return nil
    }

    let stretches = Self.stretches(
      lines.filter { nightKey($0.at, calendar) == night.night }, sleep: sleep,
      until: night.plannedEnd)
    let length = max(1, night.plannedEnd.timeIntervalSince(night.plannedStart))
    func fraction(_ date: Date) -> Double {
      min(1, max(0, date.timeIntervalSince(night.plannedStart) / length))
    }
    ran = stretches.map { Span(start: fraction($0.start), end: fraction($0.end)) }
    let holes = zip(stretches, stretches.dropFirst()).map { (start: $0.end, end: $1.start) }
    gaps = holes.map { Span(start: fraction($0.start), end: fraction($0.end)) }
    let first = stretches.first?.start ?? night.plannedStart
    let last = stretches.last?.end ?? night.plannedEnd
    from = Copy.time(first, in: calendar)
    to = Copy.time(last, in: calendar)
    putDown = outcome == .ran && night.stops > 0 ? Copy.Morning.putDown(night.stops) : nil
    eyebrow = outcome == .ran ? Copy.Morning.lockedLastNight : Copy.Morning.lastNight
    switch outcome {
    case .ran:
      spoken = Copy.Morning.spokenRan(
        from: from, to: to,
        gaps: holes.map { (Copy.time($0.start, in: calendar), Copy.time($0.end, in: calendar)) })
    case .away: spoken = Copy.Morning.spokenAway(from: from, to: to)
    case .noScreenTime: spoken = Copy.Morning.spokenNoScreenTime(from: from, to: to)
    }
  }

  /// The stretches the night's block shielded: on, and not paused. A door that's open lifts the
  /// shield (D67), so it is a gap like a time away. A stretch still open when the log stops runs to
  /// the planned end.
  static func stretches(_ lines: [Transition], sleep: Block, until end: Date) -> [(
    start: Date, end: Date
  )] {
    var stretches: [(start: Date, end: Date)] = []
    var since: Date?
    for line in lines {
      let on = line.runs(sleep) && line.door != .open
      if on, since == nil { since = line.at }
      if !on, let start = since {
        stretches.append((start, line.at))
        since = nil
      }
    }
    if let start = since { stretches.append((start, max(start, end))) }
    return stretches
  }
}

extension Transition {
  /// The night's block was on after this line, and could shield: with Screen Time off the engine
  /// still thinks it blocks, and nothing did (#60). Lines from before blocks (D29) count when
  /// anything was on.
  func runs(_ sleep: Block?) -> Bool {
    if screenTime == false { return false }
    guard let active else { return blockOn }
    return sleep.map { active.contains($0.id) } ?? false
  }
}

/// A night's key: the day it starts, noon to noon, so 1 am counts with the evening before.
func nightKey(_ date: Date, _ calendar: Calendar) -> Date {
  calendar.startOfDay(for: date.addingTimeInterval(-12 * 3600))
}
