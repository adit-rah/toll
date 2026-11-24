import Foundation

/// One Sleep night as Dusk saw it, from the transition log (#51): when the block ran, how often the
/// block screen was tapped and when last, the pauses (D67; named unlocks here and in the record), and
/// nights that couldn't block (away, paused, Screen Time off). The night record (`NightRecordLine`) carries these, beside Health's sleep
/// (#86), for the improvement measures (#87) and the sleep model (#59).
public struct NightFacts: Equatable, Sendable {
  /// The night's key: the day it starts, noon to noon (as This week keys it).
  public var night: Date
  public var plannedStart: Date
  public var plannedEnd: Date
  public var blockStart: Date?
  public var blockEnd: Date?
  /// The latest arrival home before the night ended.
  public var homeArrival: Date?
  public var away: Bool
  public var paused: Bool
  public var screenTimeOff: Bool
  /// "Never mind" taps while Sleep was on (D46).
  public var stops: Int
  /// "Pause in Dusk" taps while Sleep was on.
  public var doorAsks: Int
  /// The last time the block screen was tapped while Sleep was on: when the phone was last reached
  /// for, the stand-in for sleep onset when Health has none (#87).
  public var lastReach: Date?
  public var unlocksUsed: Int
  public var unlocksReturned: Int
  public var weekend: Bool
  /// How long the night's block shielded, pauses left out: Your sleep's hours (the audit), which the
  /// record keeps once the transition log has trimmed the night.
  public var locked: TimeInterval = 0
  /// When each "Never mind" tap was, for Your sleep's hours of the night.
  public var taps: [Date] = []

  public var ran: Bool { blockStart != nil }

  /// Every Sleep night from setup that has ended by `now`, oldest first.
  public static func ended(
    log: [Transition], sleep: Block, since setup: Date?, now: Date, calendar: Calendar,
    regret: TimeInterval = 120
  ) -> [NightFacts] {
    func key(_ date: Date) -> Date { calendar.startOfDay(for: date.addingTimeInterval(-12 * 3600)) }
    func isSleep(_ line: Transition) -> Bool {
      if line.screenTime == false { return false }
      guard let active = line.active else { return line.blockOn }
      return active.contains(sleep.id)
    }
    guard let setup else { return [] }
    let lines = log.sorted { $0.at < $1.at }
    let byNight = Dictionary(grouping: lines, by: { key($0.at) })
    var nights: [NightFacts] = []
    var day = key(setup)
    while day <= key(now) {
      defer { day = calendar.date(byAdding: .day, value: 1, to: day) ?? now.addingTimeInterval(1) }
      guard
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day),
        let start = sleep.schedule.nextStart(
          after: noon.addingTimeInterval(-1), calendar: calendar),
        start < noon.addingTimeInterval(24 * 3600),
        let occurrence = sleep.schedule.occurrence(containing: start, calendar: calendar),
        occurrence.end <= now, occurrence.end > setup
      else { continue }
      let group = byNight[day] ?? []
      var facts = NightFacts(
        night: day, plannedStart: occurrence.start, plannedEnd: occurrence.end, away: false,
        paused: false, screenTimeOff: false, stops: 0, doorAsks: 0, unlocksUsed: 0,
        unlocksReturned: 0,
        weekend: [6, 7].contains(calendar.component(.weekday, from: occurrence.start)))
      var lastSleeping: Date?
      var lockedSince: Date?
      var wasOpen = false
      var opened: Date?
      for line in group {
        let sleeping = isSleep(line)
        if sleeping {
          if facts.blockStart == nil { facts.blockStart = line.at }
          lastSleeping = line.at
          if line.cause == .blockScreen || line.cause == .doorAsked {
            if line.cause == .blockScreen {
              facts.stops += 1
              facts.taps.append(line.at)
            } else {
              facts.doorAsks += 1
            }
            facts.lastReach = line.at
          }
        } else if let last = lastSleeping, facts.blockEnd.map({ $0 < last }) ?? true {
          facts.blockEnd = line.at
        }
        if line.cause == .arrived, line.home == true, line.at < occurrence.end {
          facts.homeArrival = line.at
        }
        if !line.entitled { facts.paused = true }
        if line.screenTime == false { facts.screenTimeOff = true }
        if !sleeping, line.inWindow, line.home == false { facts.away = true }
        let isOpen = line.door == .open
        let locking = sleeping && !isOpen
        if locking, lockedSince == nil { lockedSince = line.at }
        if !locking, let since = lockedSince {
          facts.locked += line.at.timeIntervalSince(since)
          lockedSince = nil
        }
        if isOpen, !wasOpen, sleeping {
          facts.unlocksUsed += 1
          opened = line.at
        }
        if line.cause == .doorLocked, let at = opened, line.at.timeIntervalSince(at) <= regret {
          facts.unlocksUsed -= 1
          facts.unlocksReturned += 1
          opened = nil
        }
        wasOpen = isOpen
      }
      // A missed end-of-night wake still stops counting at the night's end.
      if let since = lockedSince { facts.locked += max(0, occurrence.end.timeIntervalSince(since)) }
      if facts.ran { facts.away = false }
      nights.append(facts)
    }
    return nights
  }
}
