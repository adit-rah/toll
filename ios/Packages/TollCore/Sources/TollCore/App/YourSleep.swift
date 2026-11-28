import Foundation

extension HomeSnapshot.Bar {
  /// How a night reads as a dot (D65): filled when the block ran; hollow when it didn't, with a mark
  /// for a night that couldn't block. A night that was due and didn't run is a plain hollow dot,
  /// never a dash or "missed"; it still counts as This week counts it (#44, D54).
  public enum Dot: Equatable, Sendable {
    case ran
    case hollow(Mark?)
    /// No night: before setup, or none scheduled.
    case noNight
    case ahead
  }

  public enum Mark: Equatable, Sendable {
    case away, off, noScreenTime
  }

  public var dot: Dot {
    switch night {
    case .stopped: .ran
    case .missed: .hollow(nil)
    case .away: .hollow(.away)
    case .off: .hollow(.off)
    case .noScreenTime: .hollow(.noScreenTime)
    case .noBlock: .noNight
    case .ahead: .ahead
    }
  }
}

/// Your sleep (D63, D65, #103): the nights so far, this week as seven dots, and a personal best when
/// one is true. Weeks run Monday night to Sunday night, keyed noon to noon (D67's week). Compared
/// only with the person's own past, and only when it's better; one number per card; nothing new
/// means nothing shown.
public struct YourSleep: Equatable, Sendable {
  public struct Best: Equatable, Sendable {
    public var title: String
    public var detail: String
  }

  /// "23 nights locked": every night the block ran, from the night log and the transition log together,
  /// so trimming the log never takes one away. Nil before the first.
  public var nights: String?
  /// One star for each of those nights, over the number (D79).
  public var sky: Sky
  /// "This week", "A new week" on Monday, or after the trial "Your free nights" (#48).
  public var weekTitle: String
  public var dots: [HomeSnapshot.Bar]
  /// On a new week, last week in one line over seven empty dots; nil when it had no nights.
  public var lastWeek: String?
  public var best: Best?
  /// Every ended night, for the ranges below the week (InsightsSnapshot), and the night's hours.
  public var past: [PastNight]
  public var hours: InsightsSnapshot.NightHours
  /// The next night as planned (#144): the lock before sleep, sleep, the lock after waking, as
  /// three parts. Nil with no night.
  public var plan: NightPicture?
  /// The moment this was read, so the ranges end where the rest of the tab does.
  public var now: Date
  /// The person's improvement, the tab's lead under the sky (#87, #88): the four measures, each
  /// against their own first nights.
  public var trends: SleepTrends

  public init(
    state: DuskState, log: [Transition], history: [PastNight], now: Date, calendar: Calendar,
    config: TollConfig = .defaults
  ) {
    let sleep = state.sleepBlock
    let lines = log.sorted { $0.at < $1.at }
    past = PastNight.merged(
      history: history, state: state, log: lines, now: now, calendar: calendar,
      regret: TimeInterval(config.door.regretSeconds))
    hours = InsightsSnapshot.NightHours(sleep?.schedule)
    plan = sleep.flatMap {
      NightPicture(
        $0.schedule, gap: state.gap.upcoming, after: state.after.upcoming, now: now,
        calendar: calendar)
    }
    self.now = now
    trends = SleepTrends(
      nights: past, health: state.health, now: now, calendar: calendar, config: config)
    let ran = Set(past.filter(\.ran).map(\.night))
    let total = ran.count
    nights = total > 0 ? Copy.YourSleep.nights(total) : nil
    sky = NightsRan.sky(ran, state: state, now: now, calendar: calendar, config: config)

    // The week of the night that's on or next: last night's until it ends, then tonight's.
    let inNight = sleep?.schedule.occurrence(containing: now, calendar: calendar) != nil
    let anchor = inNight ? nightKey(now, calendar) : calendar.startOfDay(for: now)
    let monday = Self.monday(of: anchor, calendar)
    let slots = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
    let week = Week(
      log: lines, now: now, calendar: calendar, since: state.setupFinishedAt, sleep: sleep,
      slots: slots, regret: TimeInterval(config.door.regretSeconds))
    dots = week.bars
    weekTitle = Copy.Home.thisWeek
    lastWeek = nil
    best = nil

    if !state.trial.entitled,
      let free = FreeNights(
        state: state, log: log, now: now, calendar: calendar, config: config)
    {
      // After the trial the free nights stands still instead of running down to blanks (#48).
      weekTitle = Copy.Purchase.eyebrow
      dots = free.bars
      return
    }
    var perWeek: [Date: Int] = [:]
    for night in ran { perWeek[Self.monday(of: night, calendar), default: 0] += 1 }
    let isNew =
      dots.allSatisfy { $0.night == .ahead } && state.setupFinishedAt.map { $0 < monday } == true
    if isNew {
      weekTitle = Copy.YourSleep.newWeek
      let previous = calendar.date(byAdding: .day, value: -7, to: monday) ?? monday
      lastWeek =
        (perWeek[previous] ?? 0) > 0 ? Copy.YourSleep.lastWeek(perWeek[previous] ?? 0) : nil
      return
    }
    // Most nights in a week, against the person's own past weeks only, and only when it's more.
    let top = perWeek.filter { $0.key < monday }.values.max() ?? 0
    if top > 0, week.blocked > top {
      // Titled by what the dots above don't show (the audit).
      best = Best(title: Copy.YourSleep.bestDetail, detail: Copy.YourSleep.best(week.blocked))
    }
  }

  /// What a tap on a star shows: the night that lit it, "Mon 23 Nov" over "Locked 10:15 pm –
  /// 7:00 am". Past the table a star belongs to several nights; it shows the latest.
  public func starNight(_ star: Int, calendar: Calendar = .current) -> StarNight? {
    let count = SkyCatalogue.stars.count
    let ran = past.filter(\.ran)
    guard star >= 0, star < count, star < ran.count else { return nil }
    let latest = star + (ran.count - 1 - star) / count * count
    let night = ran[latest]
    let locked = night.start.flatMap { start in
      night.end.map {
        Copy.Sky.locked(Copy.time(start, in: calendar), Copy.time($0, in: calendar))
      }
    }
    return StarNight(day: Copy.Sky.night(night.night, calendar: calendar), locked: locked)
  }

  public struct StarNight: Equatable, Sendable {
    public var day: String
    /// Nil when the record kept no times.
    public var locked: String?
  }

  /// The Monday that starts a day's week, whatever the phone's first weekday.
  static func monday(of day: Date, _ calendar: Calendar) -> Date {
    let back = (calendar.component(.weekday, from: day) + 5) % 7
    return calendar.date(byAdding: .day, value: -back, to: calendar.startOfDay(for: day)) ?? day
  }
}
