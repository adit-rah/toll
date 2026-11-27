import Foundation

/// One Sleep night as Dusk saw it, from the transition log (#51): when the block ran, how often the
/// block screen was tapped and when last, the pauses (D67; named unlocks here and in the record), and
/// nights that couldn't block (away, paused, Screen Time off). The night record (`NightRecordLine`) carries these, beside Health's sleep
/// (#86), for the improvement measures (#87) and the sleep model (#59).
public struct NightFacts: Equatable, Sendable {
  /// The night's key: the day it starts, noon to noon (as This week keys it).
  public var night: Date
  /// When the lock was planned to start: the gap before sleep (D76).
  public var plannedStart: Date
  /// When the lock was planned to end: the buffer after waking (#144).
  public var plannedEnd: Date
  /// Bed, when the person planned to fall asleep; the record's `planned_bedtime` (D76, #144).
  public var bed: Date
  /// Wake, the end of planned sleep; the record's `planned_wake` (#144).
  public var wake: Date
  /// Minutes the lock started before bed that night.
  public var gap: Int
  /// Minutes the lock stayed on after wake that night (#144).
  public var after: Int = 0
  public var blockStart: Date?
  public var blockEnd: Date?
  /// The latest arrival home before the night ended.
  public var homeArrival: Date?
  public var away: Bool
  public var paused: Bool
  public var screenTimeOff: Bool
  /// "Never mind" taps while Sleep was on (D46).
  public var stops: Int
  /// "Open Dusk to pause" taps while Sleep was on.
  public var doorAsks: Int
  /// The last time the block screen was tapped while Sleep was on: when the phone was last reached
  /// for, the stand-in for sleep onset when Health has none (#87).
  public var lastReach: Date?
  public var unlocksUsed: Int
  public var unlocksReturned: Int
  public var weekend: Bool
  /// The last helper opened before bed that night (D80): private, for the pilot, never shown.
  public var helper: Helper?
  /// How long the night's block shielded, pauses left out: Your sleep's hours (the audit), which the
  /// record keeps once the transition log has trimmed the night.
  public var locked: TimeInterval = 0
  /// When each "Never mind" tap was, for Your sleep's hours of the night.
  public var taps: [Date] = []
  /// Pauses opened that night by where they were asked, as Monday's rule counts them (D97): in the
  /// buffer before sleep or in the one after waking; one asked while asleep counts against neither.
  /// The buffer suggestion reads them back (#145).
  public var pausesBefore = 0
  public var pausesAfter = 0
  /// Pause waits started and cancelled (D-3), for tuning the pause's numbers (#61).
  public var waits = 0
  public var waitsCancelled = 0

  public var ran: Bool { blockStart != nil }

  /// Every Sleep night from setup that has ended by `now`, oldest first. `sleep` is the block as
  /// stored, bed to wake; each night's lock starts the gap it had then before bed (D76) and ends the
  /// buffer it had then after wake (#144).
  public static func ended(
    log: [Transition], sleep: Block, gap: Gap = Gap(), after: Gap = Gap(), since setup: Date?,
    now: Date, calendar: Calendar, regret: TimeInterval = 120
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
        let occurrence = sleep.schedule.occurrence(containing: start, calendar: calendar)
      else { continue }
      let minutes = gap.minutes(forNight: day)
      let trail = after.minutes(forNight: day)
      let end = occurrence.end.addingTimeInterval(TimeInterval(trail * 60))
      guard end <= now, end > setup else { continue }
      let group = byNight[day] ?? []
      var facts = NightFacts(
        night: day, plannedStart: occurrence.start.addingTimeInterval(-TimeInterval(minutes * 60)),
        plannedEnd: end, bed: occurrence.start, wake: occurrence.end, gap: minutes, after: trail,
        away: false, paused: false, screenTimeOff: false, stops: 0, doorAsks: 0, unlocksUsed: 0,
        unlocksReturned: 0,
        weekend: [6, 7].contains(calendar.component(.weekday, from: occurrence.start)))
      var lastSleeping: Date?
      var lockedSince: Date?
      var wasOpen = false
      var opened: Date?
      var asked: Date?
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
        if let helper = line.cause.helper { facts.helper = helper }
        if line.cause == .arrived, line.home == true, line.at < end {
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
        if sleeping, line.cause == .doorChosen {
          facts.waits += 1
          asked = line.at
        }
        if sleeping, line.cause == .doorCancelled { facts.waitsCancelled += 1 }
        if isOpen, !wasOpen, sleeping {
          facts.unlocksUsed += 1
          opened = line.at
          let at = asked ?? line.at
          if at < occurrence.start {
            facts.pausesBefore += 1
          } else if at >= occurrence.end {
            facts.pausesAfter += 1
          }
          asked = nil
        }
        if line.cause == .doorLocked, let at = opened, line.at.timeIntervalSince(at) <= regret {
          facts.unlocksUsed -= 1
          facts.unlocksReturned += 1
          opened = nil
        }
        wasOpen = isOpen
      }
      // A missed end-of-night wake still stops counting at the night's end.
      if let since = lockedSince { facts.locked += max(0, end.timeIntervalSince(since)) }
      if facts.ran { facts.away = false }
      nights.append(facts)
    }
    return nights
  }
}
