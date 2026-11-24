import Foundation

/// Everything Home shows, decided here and tested; the view only lays it out (docs/architecture.md).
public struct HomeSnapshot: Equatable, Sendable {
  /// What the big time means is the eyebrow's to say (D75): "Apps lock at", "Apps locked until",
  /// "Paused until", "Night ends at".
  public enum Hero: Equatable, Sendable {
    case tonight(start: Date, detail: String)
    case blocked(until: Date, detail: String)
    /// A pause is open (D67): the apps are open until it ends, then locked again until `nightEnd`.
    case paused(until: Date, nightEnd: Date)
    /// In the night's hours, away from home: the apps lock when you're back, until its end.
    case away(end: Date)
    /// After the trial ("Off", D70); `endedToday` reads "this morning".
    case off(endedToday: Bool)
    /// Screen Time is off for Dusk after setup: nothing can be blocked, so nothing claims it is (#45).
    case screenTimeOff
    case noBlocks
  }

  /// The quiet pill under the bar (the canvas): the free night, or the last one in amber (D33). It
  /// opens the purchase sheet (D75). Away from home is the hero's to say, so there's no label for it.
  public struct Pill: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
      case trial, lastNight
    }

    public var text: String
    public var kind: Kind
    /// The free night it is (from 1), drawn as segments beside the words (#77).
    public var night: Int
    public var nights = 7
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
  /// The whole day as a strip, every block on it (D75).
  public var timeline: DayTimeline?
  /// The last seven nights, as the morning card's dots draw them (#103).
  public var bars: [Bar]
  /// From the end of the night until noon, last night in place of the "starts at" hero (#103).
  public var morning: Morning?
  /// Over the big time, what it means: "Apps lock at", "Apps locked until" (D75).
  public var eyebrow: String
  /// With no night to show, the night's editor is the way forward (the audit's dead end).
  public var setNight: BlockID?
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
    // No selling at night (D33), away included; with no night there's nothing to sell yet.
    switch hero {
    case .away, .noBlocks: pill = nil
    default: break
    }
    if hero == .noBlocks { setNight = sleep?.id }
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
    var day = DayTimeline(state: state, now: now, calendar: calendar, blocking: !screenTimeOff)
    eyebrow = Self.eyebrow(hero, now: now, calendar: calendar)
    let week = Week(
      log: log, now: now, calendar: calendar, since: state.setupFinishedAt, sleep: sleep)
    bars = week.bars
    if case .tonight(let start, _) = hero {
      morning = Morning(state: state, log: log, now: now, calendar: calendar, config: config)
      // The morning card is last night, so the strip under it names tonight (the audit).
      if morning != nil { day.label = Copy.Strip.tonightAt(Copy.time(start, in: calendar)) }
    }
    timeline = day.segments.isEmpty ? nil : day
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
      if let door = state.door, door.phase == .open, let until = door.expiresAt {
        return .paused(until: min(until, end), nightEnd: end)
      }
      return .blocked(
        until: end,
        detail: sleep.place != nil && state.location == .places ? Copy.Home.youreHome : "")
    }
    guard let sleep, let start = sleep.schedule.nextStart(after: now, calendar: calendar) else {
      return .noBlocks
    }
    let usesHome = sleep.place != nil && state.location == .places
    let atHome = usesHome && sleep.place.flatMap { state.presence[$0]?.isInside } == true
    if usesHome, !atHome, let night = sleep.schedule.occurrence(containing: now, calendar: calendar)
    {
      return .away(end: night.end)
    }
    // Home not set (D68): the night runs on its hours wherever the phone is, and says so plainly.
    if sleep.place == nil {
      return .tonight(
        start: start,
        detail: Copy.Home.anywhereStartsIn(Copy.Home.duration(start.timeIntervalSince(now))))
    }
    // Without location it runs wherever the phone is (D37): the same words as home not set, since
    // the start is already the big time.
    if state.location == .scheduleOnly {
      return .tonight(
        start: start,
        detail: Copy.Home.anywhereStartsIn(Copy.Home.duration(start.timeIntervalSince(now))))
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
      // Not while a pause is already asked for or open: one at a time (D-7).
      offersPause: !heroOffersPause && state.door == nil && (unlocksLeft ?? 0) > 0)
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

  /// Over the big time (D75). Tonight's start is "Apps lock at"; a start that isn't tonight names its
  /// day, so a weekday night seen on a Friday doesn't read as tonight. A night starting after
  /// midnight still counts as tonight.
  static func eyebrow(_ hero: Hero, now: Date, calendar: Calendar) -> String {
    switch hero {
    case .tonight(let start, _):
      let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
      if calendar.isDate(start, inSameDayAs: now)
        || (calendar.isDate(start, inSameDayAs: tomorrow)
          && calendar.component(.hour, from: start) < 6)
      {
        return Copy.Home.locksAt
      }
      if calendar.isDate(start, inSameDayAs: tomorrow) { return Copy.Home.locksTomorrowAt }
      return Copy.Home.locksOn(
        start.formatted(
          Date.FormatStyle(calendar: calendar, timeZone: calendar.timeZone).weekday(.wide)))
    case .blocked: return Copy.Home.blockedUntil
    case .paused: return Copy.Home.pausedUntil
    case .away: return Copy.Home.nightEndsAt
    case .off: return Copy.Home.isOff
    case .screenTimeOff: return Copy.Home.screenTimeOffEyebrow
    case .noBlocks: return Copy.Home.yourNight
    }
  }
}
