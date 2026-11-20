import Foundation
import Testing

@testable import TollCore

/// Home's This week counts Sleep nights and "Never mind" taps only (#44, D24).
struct HomeWeekTests {
  let sleep = BlockID("sleep")
  let study = BlockID("study")

  func state(setup: Date = date(2026, 11, 1, 12)) -> DuskState {
    var s = setUp()
    s.places.append(libraryPlace)
    s.blocks.append(studyBlock())
    s.setupFinishedAt = setup
    return s
  }

  func line(
    _ at: Date, _ cause: ReconcileCause, active: [BlockID], home: Bool? = true,
    inWindow: Bool = true, entitled: Bool = true
  ) -> Transition {
    Transition(
      at: at, cause: cause, blockOn: !active.isEmpty, changed: false, home: home,
      inWindow: inWindow, entitled: entitled, active: active)
  }

  /// Sleep on from 10:30 pm on each of these November days.
  func nights(_ days: [Int]) -> [Transition] {
    days.map { line(date(2026, 11, $0, 22, 30), .windowStart, active: [sleep]) }
  }

  func week(_ s: DuskState, _ now: Date, _ log: [Transition]) -> HomeSnapshot {
    HomeSnapshot(state: s, log: log.sorted { $0.at < $1.at }, now: now, calendar: london)
  }

  @Test func studyNeitherMarksANightNorStopsIt() {
    var log = nights([10, 11, 12, 13, 14, 15])
    // Study on at 9 am on the 17th, a tap at 2 pm: neither is Sleep's.
    log.append(line(date(2026, 11, 17, 9), .windowStart, active: [study], inWindow: false))
    log.append(line(date(2026, 11, 17, 14), .blockScreen, active: [study], inWindow: false))
    // Sleep didn't run on the 16th, and Study's morning wake doesn't fill it in.
    let home = week(state(), date(2026, 11, 17, 23, 30), log + nights([17]))
    #expect(home.bars.map(\.night).suffix(2) == [.missed, .stopped(0)])
    #expect(home.timesStopped == 0)
    #expect(home.nightsBlocked == 6)
  }

  @Test func unlockTapsAreNotStops() {
    var log = nights([11, 12, 13, 14, 15, 16])
    log.append(line(date(2026, 11, 16, 23), .blockScreen, active: [sleep]))
    log.append(line(date(2026, 11, 16, 23, 5), .doorAsked, active: [sleep]))
    log.append(line(date(2026, 11, 16, 23, 6), .doorAsked, active: [sleep]))
    let home = week(state(), date(2026, 11, 17, 9), log)
    #expect(home.bars.last?.night == .stopped(1))
    #expect(home.timesStopped == 1)
  }

  @Test func awayAndPausedNightsAreNamedNotCounted() {
    var log = nights([11, 12, 14, 16])
    log.append(line(date(2026, 11, 13, 22, 30), .windowStart, active: [], home: false))
    log.append(line(date(2026, 11, 15, 22, 30), .windowStart, active: [], entitled: false))
    let home = week(state(), date(2026, 11, 17, 9), log)
    #expect(
      home.bars.map(\.night) == [
        .missed, .stopped(0), .stopped(0), .away, .stopped(0), .off, .stopped(0),
      ])
    #expect(home.nightsBlocked == 4)
    #expect(home.nightsCounted == 5)
  }

  @Test func theLatestNightIsLastNightUntilTonightsBlockComesOn() {
    let log = nights(Array(10...16))
    let evening = week(state(), date(2026, 11, 17, 19), log)
    #expect(evening.bars.last?.night == .ahead)
    #expect(evening.bars.firstIndex(where: \.isLatest) == 5)
    let blocked = week(state(), date(2026, 11, 17, 23), log + nights([17]))
    #expect(blocked.bars.firstIndex(where: \.isLatest) == 6)
  }

  @Test func aBusyLogStillHoldsTheWholeWeek() {
    var log: [Transition] = []
    for day in 1...16 {
      for minute in 0..<30 {
        log.append(
          line(date(2026, 11, day, 9, minute), .windowStart, active: [study], inWindow: false))
      }
    }
    let home = week(state(), date(2026, 11, 17, 9), log + nights(Array(1...16)))
    #expect(home.bars.allSatisfy { $0.night == .stopped(0) })
    #expect(home.nightsBlocked == 7)
  }

  @Test func beforeTheFirstNightItSaysWhenItStarts() {
    let home = week(state(setup: date(2026, 11, 17, 15)), date(2026, 11, 17, 19), [])
    #expect(home.firstWeekLine.hasPrefix("Your first night starts at"))
    #expect(home.bars.allSatisfy { $0.night == .ahead })
  }

  @Test func theUnlocksAreAlwaysThere() {
    var s = state()
    s.unlocks.spent = 1
    s.unlocks.cleanNights = 3
    let home = week(s, date(2026, 11, 17, 15), [])
    #expect(home.supply == .init(left: 2, max: 3, nightsToRefill: 4))
    #expect(home.unlocksLeft == nil)
  }
}
