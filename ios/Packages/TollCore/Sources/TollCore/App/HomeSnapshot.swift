import Foundation

/// Everything Home shows, decided here and tested; the view only lays it out (docs/architecture.md).
public struct HomeSnapshot: Equatable, Sendable {
  public enum Hero: Equatable, Sendable {
    case tonight(start: Date, detail: String)
    case blocked(label: String, until: Date, detail: String)
    case away(start: Date)
    case paused
    case noBlocks
  }

  public struct Pill: Equatable, Sendable {
    public var text: String
    /// Only on the last free day (D33).
    public var opensPurchase: Bool
  }

  /// Fractions of the 6 pm → 10 am strip.
  public struct Timeline: Equatable, Sendable {
    public var start: Double
    public var end: Double
    public var now: Double?
    public var label: String
  }

  public struct Bar: Equatable, Sendable {
    public var day: String
    public var count: Int
    public var isToday: Bool
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
  public var unlocksLeft: Int?
  public var locationBanner: Bool
  public var timeline: Timeline?
  public var nightsBlocked: Int
  public var nightsCounted: Int
  public var timesStopped: Int
  public var bars: [Bar]
  public var showsTrends: Bool
  public var blocks: [BlockRow]

  public init(
    state: DuskState, log: [Transition], now: Date, calendar: Calendar,
    config: TollConfig = .defaults
  ) {
    let sleep = state.sleepBlock
    hero = Self.hero(state, sleep: sleep, now: now, calendar: calendar)
    pill = Self.pill(state, now: now, calendar: calendar, config: config)
    unlocksLeft = state.isBlocking ? state.unlocks.left(config) : nil
    locationBanner = state.setupFinishedAt != nil && state.location == .scheduleOnly
    timeline = sleep.flatMap { Self.timeline($0.schedule, now: now, calendar: calendar) }
    let week = Week(log: log, now: now, calendar: calendar, since: state.setupFinishedAt)
    nightsBlocked = week.blocked
    nightsCounted = week.counted
    timesStopped = week.bars.map(\.count).reduce(0, +)
    bars = week.bars
    showsTrends = week.counted >= 3
    blocks = state.blocks.map { Self.row($0, state: state, now: now, calendar: calendar) }
  }

  // MARK: Parts

  static func hero(_ state: DuskState, sleep: Block?, now: Date, calendar: Calendar) -> Hero {
    guard state.trial.entitled else { return .paused }
    if let (block, end) = state.activeBlocks.compactMap({ b in
      state.runtime.active[b.id].map { (b, $0) }
    })
    .max(by: { $0.1 < $1.1 }) {
      let label = block.isSleep ? Copy.Home.blockedUntil : Copy.Home.blockUntil(block.name)
      let atHome = block.place != nil && state.location == .places
      return .blocked(
        label: label, until: end,
        detail: block.isSleep && atHome ? Copy.Home.youreHome : Copy.Home.onNow)
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
    return .tonight(
      start: start,
      detail: Copy.Home.startsIn(Copy.Home.duration(start.timeIntervalSince(now)), atHome: atHome))
  }

  /// No selling at night: hidden while anything is blocked (D33).
  static func pill(_ state: DuskState, now: Date, calendar: Calendar, config: TollConfig) -> Pill? {
    guard !state.trial.purchased, !state.isBlocking, let start = state.trial.start,
      let night = Trial.night(
        since: start, now: now, sleep: state.sleepBlock?.schedule, calendar: calendar,
        config: config)
    else { return nil }
    if night == config.trial.nights {
      return Pill(text: Copy.Home.lastNightPill, opensPurchase: true)
    }
    return Pill(text: Copy.Home.nightPill(night, of: config.trial.nights), opensPurchase: false)
  }

  static func timeline(_ schedule: WeeklySchedule, now: Date, calendar: Calendar) -> Timeline? {
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
    return Timeline(
      start: fraction(night.start), end: fraction(night.end),
      now: (0...span).contains(elapsed) ? fraction(now) : nil,
      label: Copy.Home.timelineLabel(
        start: Copy.time(night.start, in: calendar), end: Copy.time(night.end, in: calendar)))
  }

  static func row(_ block: Block, state: DuskState, now: Date, calendar: Calendar) -> BlockRow {
    var parts: [String] = []
    if let place = state.place(block.place) { parts.append(place.name) }
    if let window = block.schedule.windows.first {
      parts.append(Copy.span(window, in: calendar, short: true))
    }
    if let days = Self.days(block.schedule) { parts.append(days) }
    let trailing: (String, Bool)
    if !block.isOn || !state.trial.entitled {
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

/// The last seven nights from the log: which had a block on, and how many times the block screen was
/// tapped (D24). A night is keyed by the day twelve hours before, so 1 am counts with the evening.
struct Week {
  var bars: [HomeSnapshot.Bar] = []
  var blocked = 0
  var counted = 0

  init(log: [Transition], now: Date, calendar: Calendar, since setup: Date?) {
    func key(_ date: Date) -> Date { calendar.startOfDay(for: date.addingTimeInterval(-12 * 3600)) }
    let tonight = key(now)
    let days = (0..<7).reversed().compactMap {
      calendar.date(byAdding: .day, value: -$0, to: tonight)
    }
    let first = setup.map(key)
    var stops: [Date: Int] = [:]
    var on = Set<Date>()
    for line in log {
      let night = key(line.at)
      if line.cause == .blockScreen { stops[night, default: 0] += 1 }
      if line.blockOn && line.changed { on.insert(night) }
    }
    let style = Date.FormatStyle(calendar: calendar, timeZone: calendar.timeZone).weekday(
      .abbreviated)
    bars = days.map {
      HomeSnapshot.Bar(day: $0.formatted(style), count: stops[$0] ?? 0, isToday: $0 == tonight)
    }
    let counting = days.filter { day in first.map { day >= $0 } ?? true && day < tonight }
    counted = counting.count
    blocked = counting.filter(on.contains).count
  }
}

/// Settings' "Last night" (the design canvas): when the block last came on, and when it went off.
public struct LastNight: Equatable, Sendable {
  public var on: Date
  public var off: Date?

  /// The latest stretch with the block on, from the log (newest last).
  public init?(log: [Transition]) {
    guard let start = log.lastIndex(where: { $0.blockOn && $0.changed }) else { return nil }
    on = log[start].at
    off = log[start...].first(where: { !$0.blockOn && $0.changed })?.at
  }
}
