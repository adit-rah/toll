import Foundation
import Testing

@testable import TollCore

/// D-1 to D-7 (spec §11: door spend, regret return and refill counting).
struct DoorTests {
  let london = calendar("Europe/London")
  let config = TollConfig.defaults
  let app = Data([1, 2, 3])

  func blocked(at now: Date = date(2026, 11, 17, 23)) -> SleepState {
    var state = SleepState()
    state.settings = SleepSettings(window: usual)
    state.presence = Presence(isHome: true, at: now)
    run(&state, now)
    return state
  }

  func run(_ state: inout SleepState, _ now: Date, _ cause: ReconcileCause = .foreground) {
    Reconcile.run(
      &state, wall: now,
      monotonic: MonotonicInstant(bootID: "b", seconds: now.timeIntervalSinceReferenceDate),
      calendar: london, cause: cause, config: config)
  }

  @Test func spendsWhenTheAppOpensNotWhenTheWaitStarts() {
    var s = blocked()
    let chosen = date(2026, 11, 17, 23)
    #expect(DoorRules.start(&s, app: app, now: chosen, config: config) == nil)
    #expect(s.unlocks.left(config) == 3)
    run(&s, chosen.addingTimeInterval(89))
    #expect(s.door?.phase == .waiting)
    run(&s, chosen.addingTimeInterval(90), .doorStart)
    #expect(s.door?.phase == .open)
    #expect(s.unlocks.left(config) == 2)
  }

  @Test func cancellingTheWaitCostsNothing() {
    var s = blocked()
    _ = DoorRules.start(&s, app: app, now: date(2026, 11, 17, 23), config: config)
    DoorRules.cancel(&s)
    run(&s, date(2026, 11, 17, 23, 5))
    #expect(s.door == nil)
    #expect(s.unlocks.left(config) == 3)
  }

  @Test func lockAgainWithinTwoMinutesReturnsTheUnlock() {
    var s = open(at: date(2026, 11, 17, 23))
    DoorRules.lockAgain(&s, now: date(2026, 11, 17, 23, 3, 29), config: config)
    #expect(s.door == nil)
    #expect(s.unlocks.left(config) == 3)
    #expect(s.unlocks.lastSpendAt == nil)
  }

  @Test func lockAgainLaterKeepsItSpent() {
    var s = open(at: date(2026, 11, 17, 23))
    DoorRules.lockAgain(&s, now: date(2026, 11, 17, 23, 3, 31), config: config)
    #expect(s.door == nil)
    #expect(s.unlocks.left(config) == 2)
  }

  @Test func usageThresholdClosesTheDoor() {
    var s = open(at: date(2026, 11, 17, 23))
    DoorRules.usedUp(&s)
    run(&s, date(2026, 11, 17, 23, 7), .doorUsed)
    #expect(s.door == nil)
    #expect(s.blockOn)
  }

  @Test func missedCallbacksCloseAtTheStoredExpiry() {
    var s = open(at: date(2026, 11, 17, 23))
    run(&s, date(2026, 11, 17, 23, 16))
    #expect(s.door?.phase == .open)
    run(&s, date(2026, 11, 17, 23, 17))
    #expect(s.door == nil)
  }

  @Test func oneDoorAtATimeAndOnlyDuringABlock() {
    var s = blocked()
    _ = DoorRules.start(&s, app: app, now: date(2026, 11, 17, 23), config: config)
    #expect(
      DoorRules.start(&s, app: app, now: date(2026, 11, 17, 23), config: config) == .alreadyOpen)
    var day = SleepState()
    #expect(
      DoorRules.start(&day, app: app, now: date(2026, 11, 17, 15), config: config) == .notBlocked)
  }

  @Test func noDoorWithNoneLeft() {
    var s = blocked()
    s.unlocks.spent = 3
    #expect(DoorRules.start(&s, app: app, now: date(2026, 11, 17, 23), config: config) == .noneLeft)
  }

  @Test func theBlockEndingEndsTheDoor() {
    var s = open(at: date(2026, 11, 18, 6, 58))
    run(&s, date(2026, 11, 18, 7), .windowEnd)
    #expect(s.door == nil)
    #expect(s.unlocks.left(config) == 2)
  }

  @Test func sevenCleanNightsReturnOne() {
    var s = open(at: date(2026, 11, 17, 23))
    run(&s, date(2026, 11, 18, 8))
    #expect(s.unlocks.cleanNights == 0)
    for day in 19...24 { run(&s, date(2026, 11, day, 8)) }
    #expect(s.unlocks.left(config) == 2)
    #expect(s.unlocks.nightsToRefill(config) == 1)
    run(&s, date(2026, 11, 25, 8))
    #expect(s.unlocks.left(config) == 3)
    #expect(s.unlocks.nightsToRefill(config) == nil)
  }

  @Test func aSpendResetsTheRun() {
    var s = open(at: date(2026, 11, 17, 23))
    for day in 18...22 { run(&s, date(2026, 11, day, 8)) }
    #expect(s.unlocks.cleanNights == 4)
    s.presence = Presence(isHome: true, at: date(2026, 11, 22, 23))
    run(&s, date(2026, 11, 22, 23))
    _ = DoorRules.start(&s, app: app, now: date(2026, 11, 22, 23), config: config)
    run(&s, date(2026, 11, 22, 23, 2))
    run(&s, date(2026, 11, 23, 8))
    #expect(s.unlocks.cleanNights == 0)
    #expect(s.unlocks.left(config) == 1)
  }

  @Test func nightsCountWhenAwayToo() {
    var s = open(at: date(2026, 11, 17, 23))
    s.presence = Presence(isHome: false, at: date(2026, 11, 18, 9))
    run(&s, date(2026, 11, 18, 8))
    run(&s, date(2026, 11, 21, 8))
    #expect(s.unlocks.cleanNights == 3)
  }

  @Test func countsNightEndsAcrossAGap() {
    let ends = usual.ends(
      after: date(2026, 11, 17, 7), through: date(2026, 11, 20, 7), calendar: london)
    #expect(ends == [date(2026, 11, 18, 7), date(2026, 11, 19, 7), date(2026, 11, 20, 7)])
  }

  private func open(at now: Date) -> SleepState {
    var s = blocked(at: now)
    _ = DoorRules.start(&s, app: app, now: now, config: config)
    run(&s, now.addingTimeInterval(90), .doorStart)
    return s
  }
}
