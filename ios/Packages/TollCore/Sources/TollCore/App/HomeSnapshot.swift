import Foundation

/// Everything Home shows, decided here and tested; the view only lays it out (docs/architecture.md).
public struct HomeSnapshot: Equatable, Sendable {
  public enum Hero: Equatable, Sendable {
    case tonight(start: Date, detail: String)
    case blocked(label: String, until: Date, detail: String)
    case away(start: Date)
    /// After the trial ("Off", D70); `endedToday` reads "this morning".
    case off(endedToday: Bool)
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
    /// The free night it is (from 1), drawn as segments beside the words (#77); nil for away.
    public var night: Int?
    public var nights = 7

    public var opensPurchase: Bool { kind == .lastNight }
  }

  /// Fractions of the day strip: the boards' 6 pm → 10 am when tonight and now fit in it, otherwise
  /// a span fitted to both, so any block's hours show (#82).
  public struct Timeline: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
      /// Drawn as an outline: tonight's block, still to come.
      case upcoming
      /// Solid: on now.
      case on
      /// Dashed: the trial is over and nothing will block.
      case off
    }

    public var start: Double
    public var end: Double
    /// Where now is; 0 in the afternoon before the strip begins (the canvas draws the line at its
    /// left edge then, without the word).
    public var now: Double?
    public var nowInside: Bool
    public var phase: Phase
    public var label: String
    /// Five hour labels, evenly spaced from the strip's start to its end ("6 pm" … "10 am").
    public var hours: [String] = []
  }

  /// A block other than the night that's on now (D68, #89): Tonight's one quiet line about other
  /// blocks, under the state. Nothing else on Tonight mentions them.
  public struct OtherBlock: Equatable, Sendable {
    /// The block that ends last, for the line's glyph.
    public var kind: Block.Kind
    /// "Study on until 5:00 pm", or "2 blocks on until 5:00 pm".
    public var text: String
    /// The pause lifts every block (D67); the line offers it when the hero doesn't already.
    public var offersPause: Bool
  }

  /// Where tonight's block runs, for the glyph before the hero's line: at Home, or anywhere on its
  /// hours (D37). Nil when neither applies.
  public enum HeroPlace: Equatable, Sendable {
    case home, anywhere
  }

  public var hero: Hero
  public var pill: Pill?
  /// Set while a block is on: the hero's dots and its "Pause" capsule.
  public var unlocksLeft: Int?
  public var supply: Supply
  public var locationBanner: Bool
  public var heroPlace: HeroPlace?
  /// The one way Dusk fails completely: Screen Time switched off after setup (#45). Takes the
  /// location card's place.
  public var screenTimeOff: Bool
  /// The one optional card under the pill when no warning holds the slot (#102).
  public var card: TonightCard?
  /// The first heads-up the night would get, for the card that offers it (#104).
  public var headsUp: HeadsUp?
  public var timeline: Timeline?
  /// The last seven nights, as the morning card's dots draw them (#103).
  public var bars: [Bar]
  /// From the end of the night until noon, last night in place of the "starts at" hero (#103).
  public var morning: Morning?
  /// Under tonight's start: "8 h 30 m phone-free tonight" (#103).
  public var phoneFree: String?
  /// The free nights' facts, for the purchase sheet.
  public var freeWeek: FreeWeek?
  public var otherBlock: OtherBlock?

  public init(
    state: DuskState, log: [Transition], now: Date, calendar: Calendar,
    config: TollConfig = .defaults, screenTime: Bool = true,
    notifications: NotificationPermission = .allowed
  ) {
    let sleep = state.sleepBlock
    screenTimeOff = state.setupFinishedAt != nil && !screenTime
    hero = Self.hero(state, sleep: sleep, now: now, calendar: calendar, config: config)
    if screenTimeOff, state.trial.entitled { hero = .screenTimeOff }
    pill = Self.pill(state, now: now, calendar: calendar, config: config)
    supply = Supply(state: state, now: now, calendar: calendar, config: config)
    unlocksLeft = state.isBlocking && !screenTimeOff ? supply.left : nil
    if case .away = hero { pill = Pill(text: Copy.Home.awayLabel, kind: .away) }
    // Only a night at home loses anything without Always; with home not set, nothing does (D68).
    // Another block at a place says so on Blocks, since Tonight doesn't mention other blocks.
    locationBanner =
      state.setupFinishedAt != nil && state.location == .scheduleOnly && sleep?.place != nil
    card = Self.card(
      state, now: now, calendar: calendar, warning: screenTimeOff || locationBanner,
      notifications: notifications)
    if card == .headsUp {
      headsUp =
        HeadsUp.nights(
          state, screenTime: screenTime, now: now, calendar: calendar, config: config
        ).first
    }
    heroPlace =
      sleep == nil
      ? nil : state.location == .scheduleOnly ? .anywhere : sleep?.place != nil ? .home : .anywhere
    let phase: Timeline.Phase =
      !state.trial.entitled || screenTimeOff
      ? .off
      : (sleep.map { state.runtime.active[$0.id] != nil } == true
        ? .on : .upcoming)
    timeline = sleep.flatMap {
      Self.timeline($0.schedule, phase: phase, now: now, calendar: calendar)
    }
    let week = Week(
      log: log, now: now, calendar: calendar, since: state.setupFinishedAt, sleep: sleep)
    bars = week.bars
    if case .tonight(let start, _) = hero {
      morning = Morning(state: state, log: log, now: now, calendar: calendar, config: config)
      phoneFree =
        morning == nil ? Self.phoneFree(sleep, start: start, now: now, calendar: calendar) : nil
    }
    freeWeek = FreeWeek(state: state, log: log, now: now, calendar: calendar, config: config)
    if case .off = hero { supply.refillDay = nil }
    if !screenTimeOff {
      otherBlock = Self.otherBlock(state, hero: hero, unlocksLeft: unlocksLeft, calendar: calendar)
    }
  }

  // MARK: Parts

  static func hero(
    _ state: DuskState, sleep: Block?, now: Date, calendar: Calendar, config: TollConfig
  ) -> Hero {
    guard state.trial.entitled else {
      return .off(
        endedToday: Self.trialEndedToday(state, now: now, calendar: calendar, config: config))
    }
    // Only the night takes the hero; another block that's on is one quiet line under it (D68).
    if let sleep, let end = state.runtime.active[sleep.id] {
      return .blocked(
        label: Copy.Home.blockedUntil, until: end,
        detail: Copy.Home.blockedDetail(
          atHome: sleep.place != nil && state.location == .places,
          unlocksLeft: state.unlocks.left(config, now: now, calendar: calendar)))
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
    // Home not set (D68): the night runs on its hours wherever the phone is, and says so plainly.
    if sleep.place == nil {
      return .tonight(
        start: start,
        detail: Copy.Home.anywhereStartsIn(Copy.Home.duration(start.timeIntervalSince(now))))
    }
    if state.location == .scheduleOnly {
      return .tonight(
        start: start, detail: Copy.Home.startsAtAnywhere(Copy.time(start, in: calendar)))
    }
    return .tonight(
      start: start,
      detail: Copy.Home.startsIn(Copy.Home.duration(start.timeIntervalSince(now)), atHome: atHome))
  }

  /// The other blocks on now, as one line: the one that ends last names the time.
  static func otherBlock(
    _ state: DuskState, hero: Hero, unlocksLeft: Int?, calendar: Calendar
  ) -> OtherBlock? {
    guard state.trial.entitled else { return nil }
    let on = state.blocks.filter { !$0.isSleep }.compactMap { block in
      state.runtime.active[block.id].map { (block, $0) }
    }
    guard let (last, end) = on.max(by: { $0.1 < $1.1 }) else { return nil }
    let time = Copy.time(end, in: calendar)
    let heroOffersPause = if case .blocked = hero { true } else { false }
    return OtherBlock(
      kind: last.kind,
      text: on.count == 1
        ? Copy.Home.otherBlockOn(last.name, until: time)
        : Copy.Home.otherBlocksOn(on.count, until: time),
      offersPause: !heroOffersPause && (unlocksLeft ?? 0) > 0)
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
      return Pill(
        text: Copy.Home.lastNightPill, kind: .lastNight, night: night, nights: config.trial.nights)
    }
    return Pill(
      text: Copy.Home.nightPill(night, of: config.trial.nights), kind: .trial, night: night,
      nights: config.trial.nights)
  }

  static func timeline(
    _ schedule: WeeklySchedule, phase: Timeline.Phase, now: Date, calendar: Calendar
  ) -> Timeline? {
    // The night on now, or the next one: the strip shows where now is and when it happens.
    guard
      let night = schedule.occurrence(containing: now, calendar: calendar)
        ?? schedule.nextStart(after: now, calendar: calendar).flatMap({
          schedule.occurrence(containing: $0, calendar: calendar)
        })
    else { return nil }
    let (spanStart, step) = Self.span(night: night, now: now, calendar: calendar)
    let span = TimeInterval(step * 4 * 3600)
    func fraction(_ date: Date) -> Double {
      min(1, max(0, date.timeIntervalSince(spanStart) / span))
    }
    let elapsed = now.timeIntervalSince(spanStart)
    let inside = (0...span).contains(elapsed)
    let hours = (0...4).map {
      Copy.time(
        spanStart.addingTimeInterval(TimeInterval($0 * step * 3600)), in: calendar, short: true)
    }
    return Timeline(
      start: fraction(night.start), end: fraction(night.end),
      now: inside || elapsed < 0 ? fraction(now) : nil, nowInside: inside,
      phase: phase,
      label: Copy.Home.timelineLabel(
        start: Copy.time(night.start, in: calendar), end: Copy.time(night.end, in: calendar)),
      hours: hours)
  }

  /// The strip's start and its label step in hours (the strip is four steps long). The boards'
  /// 6 pm → 10 am (4 h steps) when the night fits in it and now is in it or the afternoon before;
  /// otherwise whole hours from an hour before the earlier of now and the start to an hour after the
  /// end, widened to four equal steps (#82).
  static func span(night: TimeWindow.Night, now: Date, calendar: Calendar) -> (Date, Int) {
    let evening = calendar.startOfDay(for: night.start.addingTimeInterval(-12 * 3600))
    if let six = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: evening) {
      let end = six.addingTimeInterval(16 * 3600)
      if night.start >= six, night.end <= end, now <= end,
        now >= six.addingTimeInterval(-6 * 3600)
      {
        return (six, 4)
      }
    }
    func hourFloor(_ date: Date) -> Date {
      calendar.dateInterval(of: .hour, for: date)?.start ?? date
    }
    let start = hourFloor(min(now, night.start)).addingTimeInterval(-3600)
    let end = night.end.addingTimeInterval(3600)
    let hours = Int((end.timeIntervalSince(start) / 3600).rounded(.up))
    // Never wider than a day: past that, now sits at the left edge.
    let step = min(6, max(2, Int((Double(hours) / 4).rounded(.up))))
    return (max(start, end.addingTimeInterval(-TimeInterval(step * 4 * 3600))), step)
  }

}
