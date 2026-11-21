import Foundation

/// Everything Home shows, decided here and tested; the view only lays it out (docs/architecture.md).
public struct HomeSnapshot: Equatable, Sendable {
  public enum Hero: Equatable, Sendable {
    case tonight(start: Date, detail: String)
    case blocked(label: String, until: Date, detail: String)
    case away(start: Date)
    /// After the trial; `endedToday` reads "this morning".
    case paused(endedToday: Bool)
    /// Screen Time is off for Dusk after setup: nothing can be blocked, so nothing claims it is (#45).
    case screenTimeOff
    case noBlocks
  }

  /// The quiet label under the bar (the canvas): the free night, the last one (which opens the
  /// purchase sheet, D33), or "Away from home".
  public struct Pill: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
      case trial, lastNight, away
    }

    public var text: String
    public var kind: Kind

    public var opensPurchase: Bool { kind == .lastNight }
  }

  /// Fractions of the 6 pm → 10 am strip.
  public struct Timeline: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
      /// Drawn as an outline: tonight's block, still to come.
      case upcoming
      /// Solid: on now.
      case on
      /// Dashed: the trial is over and nothing will block.
      case paused
    }

    public var start: Double
    public var end: Double
    /// Where now is; 0 in the afternoon before the strip begins (the canvas draws the line at its
    /// left edge then, without the word).
    public var now: Double?
    public var nowInside: Bool
    public var phase: Phase
    public var label: String
  }

  public struct BlockRow: Equatable, Sendable, Identifiable {
    public var id: BlockID
    public var name: String
    public var kind: Block.Kind
    public var detail: String
    public var trailing: String
    public var trailingIsAccent: Bool
  }

  public var hero: Hero
  public var pill: Pill?
  /// Set while a block is on: the hero's "Open one app" link.
  public var unlocksLeft: Int?
  public var supply: Supply
  public var locationBanner: Bool
  /// The one way Dusk fails completely: Screen Time switched off after setup (#45). Takes the
  /// location card's place.
  public var screenTimeOff: Bool
  public var timeline: Timeline?
  /// Nights Sleep ran this week.
  public var nightsBlocked: Int
  /// Nights Sleep ran or was due at home; away and paused nights aren't misses (#44).
  public var nightsCounted: Int
  /// "Never mind" taps on Sleep's block screen.
  public var timesStopped: Int
  public var bars: [Bar]
  /// The chart, from the third night; before it, the slots and `firstWeekLine`.
  public var showsTrends: Bool
  public var firstWeekLine: String
  /// "This week", or after the trial "Your free week", frozen (#48).
  public var weekTitle: String
  /// The card's third number: unlocks left, or after the trial the free week's unlocks used.
  public var unlockStat: Figure
  /// The free nights' facts, for the purchase sheet.
  public var freeWeek: FreeWeek?
  public var blocks: [BlockRow]

  public init(
    state: DuskState, log: [Transition], now: Date, calendar: Calendar,
    config: TollConfig = .defaults, screenTime: Bool = true
  ) {
    let sleep = state.sleepBlock
    screenTimeOff = state.setupFinishedAt != nil && !screenTime
    hero = Self.hero(state, sleep: sleep, now: now, calendar: calendar, config: config)
    if screenTimeOff, state.trial.entitled { hero = .screenTimeOff }
    pill = Self.pill(state, now: now, calendar: calendar, config: config)
    unlocksLeft = state.isBlocking && !screenTimeOff ? state.unlocks.left(config) : nil
    supply = Supply(
      left: state.unlocks.left(config), max: config.unlocks.max,
      nightsToRefill: state.unlocks.nightsToRefill(config))
    if case .away = hero { pill = Pill(text: Copy.Home.awayLabel, kind: .away) }
    locationBanner = state.setupFinishedAt != nil && state.location == .scheduleOnly
    let phase: Timeline.Phase =
      !state.trial.entitled || screenTimeOff
      ? .paused
      : (sleep.map { state.runtime.active[$0.id] != nil } == true
        ? .on : .upcoming)
    timeline = sleep.flatMap {
      Self.timeline($0.schedule, phase: phase, now: now, calendar: calendar)
    }
    let week = Week(
      log: log, now: now, calendar: calendar, since: state.setupFinishedAt, sleep: sleep)
    nightsBlocked = week.blocked
    nightsCounted = week.counted
    timesStopped = week.bars.map(\.count).reduce(0, +)
    bars = week.bars
    showsTrends = week.bars.filter { $0.night != .ahead && $0.night != .noBlock }.count >= 3
    firstWeekLine = Self.firstWeekLine(week.bars, hero: hero, calendar: calendar)
    weekTitle = Copy.Home.thisWeek
    unlockStat = Figure(
      value: Copy.Home.unlocks(supply.left, of: supply.max), label: Copy.Home.unlocksLeftLabel)
    freeWeek = FreeWeek(state: state, log: log, now: now, calendar: calendar, config: config)
    // Paused: the free week stands still instead of running down to blanks.
    if case .paused = hero, let free = freeWeek {
      weekTitle = Copy.Purchase.eyebrow
      bars = free.bars
      nightsBlocked = free.nightsBlocked
      nightsCounted = free.nightsCounted
      timesStopped = free.timesStopped
      showsTrends = true
      unlockStat = Figure(
        value: "\(free.unlocksUsed)", label: Copy.Purchase.usedLabel(free.unlocksUsed))
      supply.nightsToRefill = nil
    }
    let blocking = !screenTimeOff
    blocks = state.blocks.map {
      Self.row($0, state: state, now: now, calendar: calendar, blocking: blocking)
    }
  }

  // MARK: Parts

  static func hero(
    _ state: DuskState, sleep: Block?, now: Date, calendar: Calendar, config: TollConfig
  ) -> Hero {
    guard state.trial.entitled else {
      return .paused(
        endedToday: Self.trialEndedToday(state, now: now, calendar: calendar, config: config))
    }
    if let (block, end) = state.activeBlocks.compactMap({ b in
      state.runtime.active[b.id].map { (b, $0) }
    })
    .max(by: { $0.1 < $1.1 }) {
      let label = block.isSleep ? Copy.Home.blockedUntil : Copy.Home.blockUntil(block.name)
      let atHome = block.place != nil && state.location == .places
      return .blocked(
        label: label, until: end,
        detail: Copy.Home.blockedDetail(
          atHome: block.isSleep && atHome, unlocksLeft: state.unlocks.left(config)))
    }
    guard let sleep, let start = sleep.schedule.nextStart(after: now, calendar: calendar) else {
      return .noBlocks
    }
    let usesHome = sleep.place != nil && state.location == .places
    let atHome = usesHome && sleep.place.flatMap { state.presence[$0]?.isInside } == true
    if usesHome, !atHome, let night = sleep.schedule.occurrence(containing: now, calendar: calendar)
    {
      return .away(start: night.start)
    }
    if state.location == .scheduleOnly {
      return .tonight(
        start: start, detail: Copy.Home.startsAtAnywhere(Copy.time(start, in: calendar)))
    }
    return .tonight(
      start: start,
      detail: Copy.Home.startsIn(Copy.Home.duration(start.timeIntervalSince(now)), atHome: atHome))
  }

  /// Under the first nights: how many blocked, or before the first, when it starts.
  static func firstWeekLine(_ bars: [Bar], hero: Hero, calendar: Calendar) -> String {
    let none = bars.allSatisfy { $0.night == .ahead || $0.night == .noBlock }
    if none, case .tonight(let start, _) = hero {
      return Copy.Home.firstNight(Copy.time(start, in: calendar))
    }
    return Copy.Home.nightsSoFar(
      bars.filter { if case .stopped = $0.night { true } else { false } }.count)
  }

  /// The free week's last night ended this morning (the canvas's "ended this morning").
  static func trialEndedToday(
    _ state: DuskState, now: Date, calendar: Calendar, config: TollConfig
  ) -> Bool {
    guard let start = state.trial.start, let schedule = state.sleepBlock?.schedule else {
      return false
    }
    let nights = config.trial.nights
    let ends = schedule.ends(after: start, through: now, calendar: calendar)
    guard ends.count >= nights else { return false }
    return calendar.isDate(ends[nights - 1], inSameDayAs: now)
  }

  /// No selling at night: hidden while anything is blocked (D33).
  static func pill(_ state: DuskState, now: Date, calendar: Calendar, config: TollConfig) -> Pill? {
    guard !state.trial.purchased, !state.isBlocking, let start = state.trial.start,
      let night = Trial.night(
        since: start, now: now, sleep: state.sleepBlock?.schedule, calendar: calendar,
        config: config)
    else { return nil }
    if night == config.trial.nights {
      return Pill(text: Copy.Home.lastNightPill, kind: .lastNight)
    }
    return Pill(text: Copy.Home.nightPill(night, of: config.trial.nights), kind: .trial)
  }

  static func timeline(
    _ schedule: WeeklySchedule, phase: Timeline.Phase, now: Date, calendar: Calendar
  ) -> Timeline? {
    let today = calendar.startOfDay(for: now)
    let hour = calendar.component(.hour, from: now)
    guard let eveningDay = calendar.date(byAdding: .day, value: hour >= 12 ? 0 : -1, to: today),
      let spanStart = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: eveningDay)
    else { return nil }
    let span: TimeInterval = 16 * 3600
    let night =
      schedule.occurrence(containing: now, calendar: calendar)
      ?? schedule.nextStart(after: spanStart, calendar: calendar).flatMap {
        schedule.occurrence(containing: $0, calendar: calendar)
      }
    guard let night, night.start < spanStart.addingTimeInterval(span) else { return nil }
    func fraction(_ date: Date) -> Double {
      min(1, max(0, date.timeIntervalSince(spanStart) / span))
    }
    let elapsed = now.timeIntervalSince(spanStart)
    let inside = (0...span).contains(elapsed)
    return Timeline(
      start: fraction(night.start), end: fraction(night.end),
      now: inside || (elapsed < 0 && hour >= 12) ? fraction(now) : nil, nowInside: inside,
      phase: phase,
      label: Copy.Home.timelineLabel(
        start: Copy.time(night.start, in: calendar), end: Copy.time(night.end, in: calendar)))
  }

  /// `blocking` is false with Screen Time off: nothing is on, whatever the schedule says (#45).
  static func row(
    _ block: Block, state: DuskState, now: Date, calendar: Calendar, blocking: Bool = true
  ) -> BlockRow {
    if blocking, let end = state.runtime.active[block.id], state.trial.entitled,
      let held = BlocksSnapshot.held(block, state: state, at: Copy.time(end, in: calendar))
    {
      return BlockRow(
        id: block.id, name: block.name, kind: block.kind, detail: held,
        trailing: Copy.Home.onNow, trailingIsAccent: true)
    }
    var parts: [String] = []
    if let place = BlocksSnapshot.placeText(block, state: state) { parts.append(place) }
    if let window = block.schedule.windows.first {
      parts.append(Copy.span(window, in: calendar, short: true))
    }
    if let days = Self.days(block.schedule) { parts.append(days) }
    let trailing: (String, Bool)
    if Engine.waitsForAlways(block, state) {
      trailing = (Copy.Blocks.waiting, false)
    } else if !block.isOn || !state.trial.entitled || !blocking {
      trailing = (block.isOn ? Copy.Home.paused : Copy.Home.off, false)
    } else if state.runtime.active[block.id] != nil {
      trailing = (Copy.Home.onNow, true)
    } else if let next = block.schedule.nextStart(after: now, calendar: calendar) {
      // "Tonight" and "Today" only for today; a Sleep night starting after midnight still counts as
      // tonight. Anything later is its weekday.
      let today = calendar.isDate(next, inSameDayAs: now)
      let afterMidnight =
        block.isSleep
        && calendar.isDate(next, inSameDayAs: now.addingTimeInterval(86_400))
        && calendar.component(.hour, from: next) < 6
      trailing =
        today || afterMidnight
        ? (block.isSleep ? Copy.Home.tonight : Copy.Home.today, true)
        : (
          next.formatted(
            Date.FormatStyle(calendar: calendar, timeZone: calendar.timeZone).weekday(.abbreviated)),
          false
        )
    } else {
      trailing = ("", false)
    }
    return BlockRow(
      id: block.id, name: block.name, kind: block.kind,
      detail: parts.joined(separator: Copy.middleDot),
      trailing: trailing.0, trailingIsAccent: trailing.1)
  }

  /// "Weekdays", "Weekends", or nothing for every day; one rule's days stand for the block.
  static func days(_ schedule: WeeklySchedule) -> String? {
    let all = schedule.rules.reduce(into: Set<Weekday>()) { $0.formUnion($1.days) }
    if all == Weekday.all { return schedule.rules.count > 1 ? Copy.Home.weekendsDiffer : nil }
    if all == Weekday.weekdays { return Copy.Home.weekdays }
    if all == [.saturday, .sunday] { return Copy.Home.weekends }
    return all.sorted().map { Copy.Home.shortDay($0) }.joined(separator: " ")
  }
}
