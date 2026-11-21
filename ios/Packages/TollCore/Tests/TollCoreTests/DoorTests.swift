import Foundation
import Testing

@testable import TollCore

/// D-1 to D-7 with the door on the clock (D31), across blocks.
struct DoorTests {
  let config = TollConfig.defaults
  let app = Data([9])

  func blocked(at now: Date = date(2026, 11, 17, 23)) -> DuskState {
    var state = setUp()
    run(&state, now)
    return state
  }

  func open(at now: Date) -> DuskState {
    var s = blocked(at: now)
    _ = apply(.startDoor(app: app), &s, now)
    run(&s, now.addingTimeInterval(90), .doorStart)
    return s
  }

  @Test func spendsWhenTheAppOpensNotWhenTheWaitStarts() {
    var s = blocked()
    let chosen = date(2026, 11, 17, 23)
    #expect(apply(.startDoor(app: app), &s, chosen) == nil)
    let started = run(&s, chosen, .doorChosen)
    #expect(started.door == .start(Door(app: app, waitEndsAt: chosen.addingTimeInterval(90))))
    #expect(s.unlocks.left(config) == 3)
    run(&s, chosen.addingTimeInterval(89))
    #expect(s.door?.phase == .waiting)
    let opened = run(&s, chosen.addingTimeInterval(90), .doorStart)
    #expect(s.door?.phase == .open)
    #expect(s.unlocks.left(config) == 2)
    #expect(opened.shield.doorApp == app)
  }

  @Test func closesAfterFiveMinutesOnTheClock() {
    var s = open(at: date(2026, 11, 17, 23))
    #expect(s.door?.expiresAt == date(2026, 11, 17, 23, 6, 30))
    run(&s, date(2026, 11, 17, 23, 6, 29))
    #expect(s.door?.phase == .open)
    let closed = run(&s, date(2026, 11, 17, 23, 6, 30), .doorEnd)
    #expect(s.door == nil)
    #expect(closed.door == .stop)
    #expect(closed.shield.doorApp == nil)
    #expect(s.isBlocking)
  }

  @Test func cancellingTheWaitCostsNothing() {
    var s = blocked()
    _ = apply(.startDoor(app: app), &s, date(2026, 11, 17, 23))
    _ = apply(.cancelDoor, &s, date(2026, 11, 17, 23, 1))
    run(&s, date(2026, 11, 17, 23, 5))
    #expect(s.door == nil)
    #expect(s.unlocks.left(config) == 3)
  }

  @Test func lockAgainWithinTwoMinutesReturnsTheUnlock() {
    var s = open(at: date(2026, 11, 17, 23))
    _ = apply(.lockDoor, &s, date(2026, 11, 17, 23, 3, 29))
    #expect(s.door == nil)
    #expect(s.unlocks.left(config) == 3)
    #expect(s.unlocks.lastSpendAt == nil)
    #expect(s.unlocks.used == 0)
  }

  @Test func lockAgainLaterKeepsItSpent() {
    var s = open(at: date(2026, 11, 17, 23))
    _ = apply(.lockDoor, &s, date(2026, 11, 17, 23, 3, 31))
    #expect(s.unlocks.left(config) == 2)
    #expect(s.unlocks.used == 1)
  }

  @Test func refusals() {
    var s = blocked()
    #expect(apply(.startDoor(app: app), &s, date(2026, 11, 17, 23)) == nil)
    #expect(apply(.startDoor(app: app), &s, date(2026, 11, 17, 23)) == .door(.alreadyOpen))
    var day = setUp()
    run(&day, date(2026, 11, 17, 15))
    #expect(apply(.startDoor(app: app), &day, date(2026, 11, 17, 15)) == .door(.notBlocked))
    var none = blocked()
    none.unlocks.spent = 3
    #expect(apply(.startDoor(app: app), &none, date(2026, 11, 17, 23)) == .door(.noneLeft))
  }

  @Test func theBlockEndingEndsTheDoor() {
    var s = open(at: date(2026, 11, 18, 6, 57))
    run(&s, date(2026, 11, 18, 7), .windowEnd)
    #expect(s.door == nil)
    #expect(s.unlocks.left(config) == 2)
  }

  /// A blocked night: Sleep on at 11 pm, the night counted at 8 am.
  func night(_ s: inout DuskState, ending day: Int) {
    run(&s, date(2026, 11, day - 1, 23))
    run(&s, date(2026, 11, day, 8))
  }

  @Test func sevenCleanNightsReturnOne() {
    var s = open(at: date(2026, 11, 17, 23))
    run(&s, date(2026, 11, 18, 8))
    #expect(s.unlocks.cleanNights == 0)
    for day in 19...24 { night(&s, ending: day) }
    #expect(s.unlocks.left(config) == 2)
    #expect(s.unlocks.nightsToRefill(config) == 1)
    night(&s, ending: 25)
    #expect(s.unlocks.left(config) == 3)
    #expect(s.unlocks.nightsToRefill(config) == nil)
  }

  @Test func aSpendInAnyBlockResetsTheRun() {
    var s = open(at: date(2026, 11, 17, 23))
    run(&s, date(2026, 11, 18, 8))
    for day in 19...22 { night(&s, ending: day) }
    #expect(s.unlocks.cleanNights == 4)
    s.places.append(libraryPlace)
    s.blocks.append(studyBlock())
    arrive(&s, libraryPlace, date(2026, 11, 23, 9))
    run(&s, date(2026, 11, 23, 10))
    _ = apply(.startDoor(app: app), &s, date(2026, 11, 23, 10))
    run(&s, date(2026, 11, 23, 10, 2))
    run(&s, date(2026, 11, 24, 8))
    #expect(s.unlocks.cleanNights == 0)
    #expect(s.unlocks.left(config) == 1)
  }

  @Test func doorIntervalIsThePlatformMinimum() {
    #expect(DoorRules.intervalMinutes(config) == 15)
  }

  @Test func theBlockScreensAppGoesWithTheRequestAndClearsWithIt() {
    var s = setUp()
    run(&s, date(2026, 11, 17, 23))
    let app = Data([1, 2, 3])
    _ = apply(.askDoor(date(2026, 11, 17, 23, 5), app: app), &s, date(2026, 11, 17, 23, 5))
    #expect(s.doorAskedFor == app)
    _ = apply(.askDoor(date(2026, 11, 17, 23, 6)), &s, date(2026, 11, 17, 23, 6))
    #expect(s.doorAskedFor == nil)
    _ = apply(.askDoor(nil, app: app), &s, date(2026, 11, 17, 23, 7))
    #expect(s.doorAskedFor == nil)
  }

  /// Cancel and Lock again close the sheet instead of offering the same app again (#47).
  @Test func startingCancellingOrLockingAnswersTheAsk() {
    var s = blocked()
    _ = apply(.askDoor(date(2026, 11, 17, 23), app: app), &s, date(2026, 11, 17, 23))
    _ = apply(.startDoor(app: app), &s, date(2026, 11, 17, 23))
    #expect(s.doorAskedAt == nil && s.doorAskedFor == nil)
    _ = apply(.askDoor(date(2026, 11, 17, 23, 1), app: app), &s, date(2026, 11, 17, 23, 1))
    _ = apply(.cancelDoor, &s, date(2026, 11, 17, 23, 1))
    #expect(s.door == nil && s.doorAskedAt == nil && s.doorAskedFor == nil)
    var opened = open(at: date(2026, 11, 17, 23))
    _ = apply(.askDoor(date(2026, 11, 17, 23, 2)), &opened, date(2026, 11, 17, 23, 2))
    _ = apply(.lockDoor, &opened, date(2026, 11, 17, 23, 2))
    #expect(opened.door == nil && opened.doorAskedAt == nil)
  }

  /// Only nights Sleep ran count toward the refill; away nights neither count nor reset (#61).
  @Test func onlyBlockedNightsCountTowardTheRefill() {
    var s = open(at: date(2026, 11, 17, 23))
    run(&s, date(2026, 11, 18, 8))
    night(&s, ending: 19)
    // Away all night 19–20: nothing ran.
    arrive(&s, homePlace, date(2026, 11, 19, 20), inside: false)
    run(&s, date(2026, 11, 19, 23), .left)
    run(&s, date(2026, 11, 20, 8))
    #expect(s.unlocks.cleanNights == 1)
    arrive(&s, homePlace, date(2026, 11, 20, 20))
    night(&s, ending: 21)
    #expect(s.unlocks.cleanNights == 2)
    // Screen Time off: Sleep "on" in the engine, but nothing was blocked.
    _ = apply(.screenTime(false), &s, date(2026, 11, 21, 20))
    night(&s, ending: 22)
    #expect(s.unlocks.cleanNights == 2)
  }
}
