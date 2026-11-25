import Foundation

extension HomeSnapshot {
  /// One night of a week: a dot on the morning card and on Your sleep (#103), a bar in the free week.
  public struct Bar: Equatable, Sendable {
    public enum Night: Equatable, Sendable {
      /// Sleep ran; "Never mind" was tapped this many times (0 is drawn as 0).
      case stopped(Int)
      /// Sleep was due and nothing blocked, and the user wasn't away: it counts, and is drawn as a
      /// plain hollow dot, never a dash or "missed" (D65).
      case missed
      /// Away from home through Sleep's hours: named, and not counted (#44).
      case away
      /// After the trial, nothing blocks: named, and not counted.
      case off
      /// Screen Time was off for Dusk, so nothing could block: named "off", spoken as what it was,
      /// counted toward the free week (P-2) but not in "N of M" (#60).
      case noScreenTime
      /// No Sleep that night, or before setup: a dash, not counted.
      case noBlock
      /// Still to come, or tonight before its block: a dashed empty slot.
      case ahead
    }

    public var day: String
    public var night: Night
    /// The newest night that isn't still ahead: last night until tonight's block comes on. Amber on
    /// the board.
    public var isLatest: Bool

    public var count: Int {
      if case .stopped(let count) = night { return count }
      return 0
    }
  }

  /// The week's pauses, always shown (D67): how many are left, and when they come back.
  public struct Supply: Equatable, Sendable {
    public var left: Int
    public var max: Int
    /// Noon on the refill day: the start of the night that brings the week's pauses back.
    public var refill: Date
    /// "Monday" ("today" on its morning) while any is spent; nil at the maximum.
    public var refillDay: String?
    /// Which of the week's seven nights it is, from 1 on the refill night: drawn as the week's
    /// segments when none are left, so how long until they come back reads without words.
    public var nightOfWeek: Int

    public init(left: Int, max: Int, refill: Date, refillDay: String?, nightOfWeek: Int) {
      self.left = left
      self.max = max
      self.refill = refill
      self.refillDay = refillDay
      self.nightOfWeek = nightOfWeek
    }

    public init(state: DuskState, now: Date, calendar: Calendar, config: TollConfig = .defaults) {
      left = state.unlocks.left(config, now: now, calendar: calendar)
      max = config.unlocks.max
      refill = UnlockSupply.refill(after: now, calendar: calendar, config: config)
      refillDay = left < max ? Copy.Door.refillDay(refill, now: now, in: calendar) : nil
      let week = UnlockSupply.week(containing: now, calendar: calendar, config: config)
      let night = UnlockSupply.night(of: now, calendar: calendar)
      nightOfWeek = (calendar.dateComponents([.day], from: week, to: night).day ?? 0) + 1
    }
  }
}

/// This week on Home, from the log (sticky note s2). In the first week, the nights since setup with
/// the rest still to come; from night 8, the last seven. A night is keyed by the day twelve hours
/// before, so 1 am counts with the evening.
///
/// Only Sleep counts: a line belongs to it when Sleep is among the blocks on after it (lines from
/// before blocks, D29, have no list and count when anything was on). A stop is a "Never mind" tap
/// while Sleep was on; "Unlock in Dusk" logs `doorAsked` and isn't one (D24, #44).
struct Week {
  var bars: [HomeSnapshot.Bar] = []
  /// The first seven nights from setup, some still to come, rather than the last seven.
  var firstWeek = false
  /// Nights Sleep ran.
  var blocked = 0
  /// Nights Sleep ran or was due at home; away and paused nights are left out.
  var counted = 0
  /// Pauses kept in these nights: one that opened while Sleep was on, less one locked again within
  /// the regret time (D-4).
  var unlocks = 0

  /// `slots` replaces the rolling week with given nights, such as the free week's.
  init(
    log: [Transition], now: Date, calendar: Calendar, since setup: Date?, sleep: Block?,
    slots given: [Date]? = nil, regret: TimeInterval = 120
  ) {
    func key(_ date: Date) -> Date { calendar.startOfDay(for: date.addingTimeInterval(-12 * 3600)) }
    func day(_ offset: Int, from base: Date) -> Date? {
      calendar.date(byAdding: .day, value: offset, to: base)
    }
    func isSleep(_ line: Transition) -> Bool {
      // With Screen Time off the engine still thinks it blocks; nothing did (#60).
      if line.screenTime == false { return false }
      guard let active = line.active else { return line.blockOn }
      return sleep.map { active.contains($0.id) } ?? false
    }
    let tonight = key(now)
    let first = setup.map(key)
    let sinceSetup = first.map { calendar.dateComponents([.day], from: $0, to: tonight).day ?? 0 }
    let firstWeek = sinceSetup.map { $0 < 7 } ?? false
    self.firstWeek = firstWeek && given == nil
    let slots: [Date] =
      given
      ?? (firstWeek
        ? (0..<7).compactMap { offset in first.flatMap { day(offset, from: $0) } }
        : (0..<7).reversed().compactMap { day(-$0, from: tonight) })

    var stops: [Date: Int] = [:]
    var ran = Set<Date>()
    var away = Set<Date>()
    var off = Set<Date>()
    var noAccess = Set<Date>()
    var kept: [Date: Int] = [:]
    var opened: (at: Date, night: Date)?
    var wasOpen = false
    for line in log.sorted(by: { $0.at < $1.at }) {
      let isOpen = line.door == .open
      if isOpen, !wasOpen, isSleep(line) {
        opened = (line.at, key(line.at))
        kept[key(line.at), default: 0] += 1
      }
      if line.cause == .doorLocked, let door = opened, line.at.timeIntervalSince(door.at) <= regret
      {
        kept[door.night, default: 0] -= 1
        opened = nil
      }
      wasOpen = isOpen
    }
    for line in log {
      let night = key(line.at)
      let sleeping = isSleep(line)
      if sleeping { ran.insert(night) }
      if sleeping, line.cause == .blockScreen { stops[night, default: 0] += 1 }
      if !line.entitled { off.insert(night) }
      if line.screenTime == false { noAccess.insert(night) }
      if !sleeping, line.inWindow, line.home == false { away.insert(night) }
    }

    /// Sleep's occurrence that starts in the slot's noon-to-noon day.
    func occurrence(_ slot: Date) -> TimeWindow.Night? {
      guard let schedule = sleep?.schedule,
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: slot),
        let start = schedule.nextStart(after: noon.addingTimeInterval(-1), calendar: calendar),
        start < noon.addingTimeInterval(24 * 3600)
      else { return nil }
      return schedule.occurrence(containing: start, calendar: calendar)
    }
    func night(_ slot: Date) -> HomeSnapshot.Bar.Night {
      if slot > tonight { return .ahead }
      if ran.contains(slot) { return .stopped(stops[slot] ?? 0) }
      let due = occurrence(slot)
      if slot == tonight, due.map({ $0.end > now }) ?? true { return .ahead }
      if let first, slot < first { return .noBlock }
      if off.contains(slot) { return .off }
      if noAccess.contains(slot) { return .noScreenTime }
      if away.contains(slot) { return .away }
      guard let due else { return .noBlock }
      if let setup, slot == first, due.start < setup { return .noBlock }
      return .missed
    }

    let style = Date.FormatStyle(calendar: calendar, timeZone: calendar.timeZone).weekday(
      .abbreviated)
    let nights = slots.map(night)
    let latest = nights.lastIndex { $0 != .ahead }
    bars = zip(slots, nights).enumerated().map { index, pair in
      HomeSnapshot.Bar(day: pair.0.formatted(style), night: pair.1, isLatest: index == latest)
    }
    blocked = nights.filter { if case .stopped = $0 { true } else { false } }.count
    counted = blocked + nights.filter { $0 == .missed }.count
    unlocks = slots.map { max(0, kept[$0] ?? 0) }.reduce(0, +)
  }
}

/// The free nights' facts (spec §7, P-2, D78): all of them, counted as This week counts (#44), and
/// frozen once they've ended, so the purchase sheet on day 20 says what it said on day 8 (#48).
public struct FreeWeek: Equatable, Sendable {
  public var bars: [HomeSnapshot.Bar]
  public var nightsBlocked: Int
  /// Nights Sleep ran or was due at home; away nights are left out.
  public var nightsCounted: Int
  public var timesStopped: Int
  public var unlocksUsed: Int

  public init?(
    state: DuskState, log: [Transition], now: Date, calendar: Calendar,
    config: TollConfig = .defaults
  ) {
    guard let start = state.trial.start else { return nil }
    let slots = Trial.nightKeys(
      since: start, sleep: state.sleepBlock?.schedule, calendar: calendar, config: config)
    guard !slots.isEmpty else { return nil }
    let week = Week(
      log: log, now: now, calendar: calendar, since: state.setupFinishedAt,
      sleep: state.sleepBlock, slots: slots, regret: TimeInterval(config.door.regretSeconds))
    bars = week.bars
    nightsBlocked = week.blocked
    nightsCounted = week.counted
    timesStopped = week.bars.map(\.count).reduce(0, +)
    unlocksUsed = week.unlocks
  }
}
