import Foundation

extension HomeSnapshot {
  /// One night in "Times it stopped you, by night" (the canvas, sticky note s2).
  public struct Bar: Equatable, Sendable {
    public enum Night: Equatable, Sendable {
      /// Sleep ran; "Never mind" was tapped this many times (0 is drawn as 0).
      case stopped(Int)
      /// Sleep was due and nothing blocked, and the user wasn't away: a dash, and it counts.
      case missed
      /// Away from home through Sleep's hours: named, and not counted (#44).
      case away
      /// After the trial, nothing blocks: named, and not counted.
      case off
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

  /// The unlocks, always shown (spec §7): how many are left, and when one comes back.
  public struct Supply: Equatable, Sendable {
    public var left: Int
    public var max: Int
    /// Nights still to go before one returns; nil at the maximum.
    public var nightsToRefill: Int?
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
  /// Nights Sleep ran.
  var blocked = 0
  /// Nights Sleep ran or was due at home; away and paused nights are left out.
  var counted = 0

  init(log: [Transition], now: Date, calendar: Calendar, since setup: Date?, sleep: Block?) {
    func key(_ date: Date) -> Date { calendar.startOfDay(for: date.addingTimeInterval(-12 * 3600)) }
    func day(_ offset: Int, from base: Date) -> Date? {
      calendar.date(byAdding: .day, value: offset, to: base)
    }
    func isSleep(_ line: Transition) -> Bool {
      guard let active = line.active else { return line.blockOn }
      return sleep.map { active.contains($0.id) } ?? false
    }
    let tonight = key(now)
    let first = setup.map(key)
    let sinceSetup = first.map { calendar.dateComponents([.day], from: $0, to: tonight).day ?? 0 }
    let firstWeek = sinceSetup.map { $0 < 7 } ?? false
    let slots: [Date] =
      firstWeek
      ? (0..<7).compactMap { offset in first.flatMap { day(offset, from: $0) } }
      : (0..<7).reversed().compactMap { day(-$0, from: tonight) }

    var stops: [Date: Int] = [:]
    var ran = Set<Date>()
    var away = Set<Date>()
    var off = Set<Date>()
    for line in log {
      let night = key(line.at)
      let sleeping = isSleep(line)
      if sleeping { ran.insert(night) }
      if sleeping, line.cause == .blockScreen { stops[night, default: 0] += 1 }
      if !line.entitled { off.insert(night) }
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
