import Foundation

/// Last night's card (D65, #103): last night from Dusk's own log, to review. It floats on Tonight
/// each morning until put away, and opens from the strip until the next night starts; the hero keeps
/// saying what tonight holds. Exact facts about the person's own night, and nothing to keep up. A
/// night that was due and didn't run has no card: a bad night is neutral and forward-looking.
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
    /// A gap where a pause was open, rather than a time away: the bar marks it with the pause's
    /// glyph, so the break doesn't read as a glitch (#124).
    public var paused = false
  }

  public var outcome: Outcome
  /// The night's key (noon to noon), which putting the card away remembers.
  public var night: Date
  /// When the night was planned to end: where the strip starts, and where last night sits on it.
  public var ended: Date
  /// When the lock was planned to start: the bar's left end.
  var started: Date
  /// Health's sleep last night (#88): the card leads with it when Health has some.
  public var asleep: Asleep?
  /// The morning after the first night that locked, for someone who didn't choose Health at
  /// setup: the card offers "See how you slept" (#86). Only that morning, so it asks once.
  public var asksHealth = false
  /// That same morning, once Health was chosen and had nothing for the night: a quiet line, so the
  /// answer visibly landed.
  public var healthEmpty = false
  /// When the block first came on and last went off; the planned hours when it didn't run.
  public var from: String
  public var to: String
  /// Where the block was on; the room between two of them is a gap (a pause, or a time away).
  public var ran: [Span]
  public var gaps: [Span]
  /// Sleep inside the night's planned hours (#144): bed to wake as fractions, so the bar draws the
  /// buffer before, sleep and the buffer after as three parts.
  public var sleep = Span(start: 0, end: 1)
  /// How long apps were locked, to the minute: the stretches added up, breaks left out.
  public var lockedMinutes: Int
  /// What the bar says, in a sentence over it: "Apps locked from 10:15 pm to 7:00 am", or why
  /// nothing locked.
  public var headline: String
  /// Under the bar when it has a break: "Apps open from 12:40 am to 12:50 am". Nil without one.
  public var openLine: String?
  /// "You chose sleep over a locked app 3 times": the "Never mind" taps while the night's block
  /// was on (D46). Nil at zero, since nothing new means nothing shown.
  public var putDown: String?
  /// The headline, the bar and its breaks in words, for VoiceOver.
  public var spoken: String
  /// "Last night": what the card is about.
  public var eyebrow = Copy.Morning.lastNight
  /// The last seven nights as dots, and what they are: "Last 7 nights" (HomeSnapshot sets both).
  public var week: [HomeSnapshot.Bar] = []
  public var weekTitle = Copy.Morning.lastSeven
  /// At 7, 30, 100 and 365 nights, a quiet line, the newly completed shape and a picture to share
  /// (D79).
  public var landmark: Sky.Landmark?

  /// The night that ended within the last day. Nil before setup, after the trial (the off hero
  /// speaks then), and when last night was due and simply didn't run. HomeSnapshot asks only while
  /// the next night hasn't started.
  init?(
    state: DuskState, log: [Transition], now: Date, calendar: Calendar,
    config: TollConfig = .defaults
  ) {
    guard state.trial.entitled, let sleep = state.sleepBlock, let setup = state.setupFinishedAt
    else { return nil }
    let lines = log.sorted { $0.at < $1.at }
    // Only last night matters, so the search starts a day and a half back rather than at setup.
    guard
      let night = NightFacts.ended(
        log: lines, sleep: sleep, gap: state.gap, after: state.after,
        since: max(setup, now.addingTimeInterval(-36 * 3600)),
        now: now, calendar: calendar, regret: TimeInterval(config.door.regretSeconds)
      ).last,
      now.timeIntervalSince(night.plannedEnd) < 24 * 3600, !night.paused
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
    self.night = night.night
    ended = night.plannedEnd
    started = night.plannedStart

    let stretches = Self.stretches(
      lines.filter { nightKey($0.at, calendar) == night.night }, sleep: sleep,
      until: night.plannedEnd)
    let length = max(1, night.plannedEnd.timeIntervalSince(night.plannedStart))
    func fraction(_ date: Date) -> Double {
      min(1, max(0, date.timeIntervalSince(night.plannedStart) / length))
    }
    ran = stretches.map { Span(start: fraction($0.start), end: fraction($0.end)) }
    self.sleep = Span(start: fraction(night.bed), end: fraction(night.wake))
    let holes = zip(stretches, stretches.dropFirst()).map { (start: $0.end, end: $1.start) }
    gaps = zip(holes, stretches).map { hole, before in
      Span(start: fraction(hole.start), end: fraction(hole.end), paused: before.paused)
    }
    let locked = stretches.reduce(0) { $0 + $1.end.timeIntervalSince($1.start) }
    lockedMinutes = Int((locked / 60).rounded())
    let first = stretches.first?.start ?? night.plannedStart
    let last = stretches.last?.end ?? night.plannedEnd
    from = Copy.time(first, in: calendar)
    to = Copy.time(last, in: calendar)
    putDown = outcome == .ran && night.stops > 0 ? Copy.Morning.putDown(night.stops) : nil
    let breaks = holes.map { (Copy.time($0.start, in: calendar), Copy.time($0.end, in: calendar)) }
    openLine = Copy.Morning.open(breaks)
    switch outcome {
    case .ran:
      headline = Copy.Morning.locked(from: from, to: to)
      spoken = Copy.Morning.spokenRan(from: from, to: to, gaps: breaks)
    case .away:
      headline = Copy.Morning.away
      spoken = Copy.Morning.spokenAway(from: from, to: to)
    case .noScreenTime:
      headline = Copy.Morning.noScreenTime
      spoken = Copy.Morning.spokenNoScreenTime(from: from, to: to)
    }
  }

  /// The folded card's status, the night at a glance: "Locked 8 h 45 m" when it ran, even with a
  /// break (the open card says the rest); "Away, nothing locked"; "Screen Time was off". On a
  /// landmark morning, the landmark's line instead (D79).
  public var status: String {
    if let landmark { return landmark.line }
    if let asleep { return asleep.status }
    switch outcome {
    case .ran:
      return Copy.Morning.statusLocked(Copy.Home.duration(TimeInterval(lockedMinutes * 60)))
    case .away: return Copy.Morning.statusAway
    case .noScreenTime: return Copy.Morning.statusNoScreenTime
    }
  }

  /// The folded card for VoiceOver: "Last night, apps locked 8 hours 45 minutes", and the landmark's
  /// line after it on a landmark morning.
  public var statusSpoken: String {
    let night =
      switch outcome {
      case _ where asleep != nil: asleep?.statusSpoken ?? ""
      case .ran: Copy.Morning.spokenLocked(minutes: lockedMinutes)
      case .away: Copy.Morning.spokenStatusAway
      case .noScreenTime: Copy.Morning.statusNoScreenTime
      }
    return Copy.Morning.spokenStatus(night, landmark: landmark?.line)
  }

  /// The stretches the night's block shielded: on, and not paused. A door that's open lifts the
  /// shield (D67), so it is a gap like a time away; `paused` says a pause ended the stretch. A
  /// stretch still open when the log stops runs to the planned end.
  static func stretches(_ lines: [Transition], sleep: Block, until end: Date) -> [(
    start: Date, end: Date, paused: Bool
  )] {
    var stretches: [(start: Date, end: Date, paused: Bool)] = []
    var since: Date?
    for line in lines {
      let on = line.runs(sleep) && line.door != .open
      if on, since == nil { since = line.at }
      if !on, let start = since {
        stretches.append((start, line.at, line.door == .open))
        since = nil
      }
    }
    if let start = since { stretches.append((start, max(start, end), false)) }
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
