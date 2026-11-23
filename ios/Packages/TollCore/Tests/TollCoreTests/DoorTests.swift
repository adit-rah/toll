import Foundation
import Testing

@testable import TollCore

/// The pause (D67): a 60 s wait, then every shield lifts for 10 minutes on the clock (D31), with
/// D-3, D-4 and D-7 kept. 17 Nov 2026 is a Tuesday.
struct DoorTests {
  let config = TollConfig.defaults

  func blocked(at now: Date = date(2026, 11, 17, 23)) -> DuskState {
    var state = setUp()
    run(&state, now)
    return state
  }

  func open(at now: Date) -> DuskState {
    var s = blocked(at: now)
    _ = apply(.startDoor, &s, now)
    run(&s, now.addingTimeInterval(60), .doorStart)
    return s
  }

  func left(_ s: DuskState, _ now: Date) -> Int {
    s.unlocks.left(config, now: now, calendar: london)
  }

  @Test func spendsWhenItOpensNotWhenTheWaitStarts() {
    var s = blocked()
    let chosen = date(2026, 11, 17, 23)
    #expect(apply(.startDoor, &s, chosen) == nil)
    let started = run(&s, chosen, .doorChosen)
    #expect(started.door == .start(Door(waitEndsAt: chosen.addingTimeInterval(60))))
    #expect(!started.shield.isOff)
    #expect(left(s, chosen) == 3)
    run(&s, chosen.addingTimeInterval(59))
    #expect(s.door?.phase == .waiting)
    let opened = run(&s, chosen.addingTimeInterval(60), .doorStart)
    #expect(s.door?.phase == .open)
    #expect(left(s, chosen) == 2)
    #expect(opened.shield.isOff)
    #expect(s.isBlocking)
  }

  @Test func shieldsComeBackAfterTenMinutesOnTheClock() {
    var s = open(at: date(2026, 11, 17, 23))
    #expect(s.door?.expiresAt == date(2026, 11, 17, 23, 11))
    #expect(run(&s, date(2026, 11, 17, 23, 10, 59)).shield.isOff)
    let closed = run(&s, date(2026, 11, 17, 23, 11), .doorEnd)
    #expect(s.door == nil)
    #expect(closed.door == .stop)
    #expect(closed.shield.selections == [Data([1])])
  }

  @Test func aPauseLiftsEveryBlocksShieldAtOnce() {
    var s = setUp()
    s.blocks.append(
      Block(
        id: BlockID("late"), name: "Late", kind: .other, place: nil,
        schedule: .everyDay(TimeWindow(start: time(22), end: time(23, 30))), apps: Data([3])))
    let before = run(&s, date(2026, 11, 17, 23))
    #expect(Set(before.shield.selections) == [Data([1]), Data([3])])
    _ = apply(.startDoor, &s, date(2026, 11, 17, 23))
    #expect(run(&s, date(2026, 11, 17, 23, 1), .doorStart).shield.isOff)
    let after = run(&s, date(2026, 11, 17, 23, 11), .doorEnd)
    #expect(Set(after.shield.selections) == [Data([1]), Data([3])])
  }

  @Test func cancellingTheWaitCostsNothing() {
    var s = blocked()
    _ = apply(.startDoor, &s, date(2026, 11, 17, 23))
    _ = apply(.cancelDoor, &s, date(2026, 11, 17, 23, 0, 30))
    run(&s, date(2026, 11, 17, 23, 5))
    #expect(s.door == nil)
    #expect(left(s, date(2026, 11, 17, 23, 5)) == 3)
  }

  @Test func lockAgainWithinTwoMinutesReturnsThePause() {
    var s = open(at: date(2026, 11, 17, 23))
    _ = apply(.lockDoor, &s, date(2026, 11, 17, 23, 2, 59))
    let effects = run(&s, date(2026, 11, 17, 23, 2, 59), .doorLocked)
    #expect(s.door == nil)
    #expect(!effects.shield.isOff)
    #expect(left(s, date(2026, 11, 17, 23, 3)) == 3)
    #expect(s.unlocks.used == 0)
  }

  @Test func lockAgainLaterKeepsItSpent() {
    var s = open(at: date(2026, 11, 17, 23))
    _ = apply(.lockDoor, &s, date(2026, 11, 17, 23, 3, 1))
    #expect(left(s, date(2026, 11, 17, 23, 4)) == 2)
    #expect(s.unlocks.used == 1)
  }

  @Test func refusals() {
    var s = blocked()
    #expect(apply(.startDoor, &s, date(2026, 11, 17, 23)) == nil)
    #expect(apply(.startDoor, &s, date(2026, 11, 17, 23)) == .door(.alreadyOpen))
    var day = setUp()
    run(&day, date(2026, 11, 17, 15))
    #expect(apply(.startDoor, &day, date(2026, 11, 17, 15)) == .door(.notBlocked))
    var none = blocked()
    none.unlocks.spent = 3
    #expect(apply(.startDoor, &none, date(2026, 11, 17, 23)) == .door(.noneLeft))
  }

  @Test func theBlockEndingEndsThePause() {
    var s = open(at: date(2026, 11, 18, 6, 57))
    run(&s, date(2026, 11, 18, 7), .windowEnd)
    #expect(s.door == nil)
    #expect(left(s, date(2026, 11, 18, 7)) == 2)
  }

  /// One pool for every block (D55, D67): a pause in Study is one fewer for the night.
  @Test func everyBlockSharesOnePool() {
    var s = setUp()
    s.places.append(libraryPlace)
    s.blocks.append(studyBlock())
    arrive(&s, libraryPlace, date(2026, 11, 17, 9))
    run(&s, date(2026, 11, 17, 10))
    _ = apply(.startDoor, &s, date(2026, 11, 17, 10))
    run(&s, date(2026, 11, 17, 10, 1), .doorStart)
    run(&s, date(2026, 11, 17, 10, 11), .doorEnd)
    run(&s, date(2026, 11, 17, 23))
    #expect(left(s, date(2026, 11, 17, 23)) == 2)
    let shield = ShieldText(
      state: s, block: s.sleepBlock, now: date(2026, 11, 17, 23), calendar: london)
    #expect(shield.unlocksLeft == 2)
  }

  /// All three spent Tuesday to Thursday: none Sunday night, still none at 1 am Monday (that's
  /// Sunday's night), and all three back at noon Monday, when Monday's night starts.
  @Test func theWeekRefillsAtTheStartOfMondaysNight() {
    var s = blocked()
    for day in 17...19 {
      _ = apply(.startDoor, &s, date(2026, 11, day, 23))
      run(&s, date(2026, 11, day, 23, 1), .doorStart)
      run(&s, date(2026, 11, day, 23, 11), .doorEnd)
    }
    #expect(left(s, date(2026, 11, 20, 23)) == 0)
    run(&s, date(2026, 11, 22, 23))
    #expect(apply(.startDoor, &s, date(2026, 11, 22, 23)) == .door(.noneLeft))
    run(&s, date(2026, 11, 23, 1))
    #expect(apply(.startDoor, &s, date(2026, 11, 23, 1)) == .door(.noneLeft))
    #expect(left(s, date(2026, 11, 23, 11, 59)) == 0)
    #expect(left(s, date(2026, 11, 23, 12)) == 3)
    run(&s, date(2026, 11, 23, 23))
    #expect(s.unlocks.spent == 0 && s.unlocks.week == date(2026, 11, 23, 0))
    #expect(apply(.startDoor, &s, date(2026, 11, 23, 23)) == nil)
  }

  /// Unused pauses don't carry over: a week with none used, or one used, starts the next at three.
  @Test func nothingCarriesOver() {
    var s = blocked()
    run(&s, date(2026, 11, 24, 23))
    #expect(left(s, date(2026, 11, 24, 23)) == 3)
    _ = apply(.startDoor, &s, date(2026, 11, 24, 23))
    run(&s, date(2026, 11, 24, 23, 1), .doorStart)
    #expect(left(s, date(2026, 11, 24, 23, 2)) == 2)
    run(&s, date(2026, 11, 30, 23))
    #expect(left(s, date(2026, 11, 30, 23)) == 3)
    #expect(s.unlocks.spent == 0)
    #expect(s.unlocks.used == 1)
  }

  /// A clock set back into an earlier week brings nothing back.
  @Test func aClockSetBackRefillsNothing() {
    var s = open(at: date(2026, 11, 24, 23))
    run(&s, date(2026, 11, 25, 8))
    #expect(left(s, date(2026, 11, 18, 23)) == 2)
    run(&s, date(2026, 11, 18, 23), monotonic: boot(date(2026, 11, 18, 23), id: "later"))
    #expect(s.unlocks.spent == 1 && s.unlocks.week == date(2026, 11, 23, 0))
  }

  /// The pause's interval is the platform's minimum, warning at its 10 minutes (D31).
  @Test func theIntervalWarnsAtTheMinutes() {
    #expect(DoorRules.intervalMinutes(config) == 15)
    #expect(DoorRules.intervalMinutes(config) - config.door.minutes == 5)
  }

  /// Cancel and Lock again close the sheet instead of offering a pause again (#47).
  @Test func startingCancellingOrLockingAnswersTheAsk() {
    var s = blocked()
    _ = apply(.askDoor(date(2026, 11, 17, 23)), &s, date(2026, 11, 17, 23))
    _ = apply(.startDoor, &s, date(2026, 11, 17, 23))
    #expect(s.doorAskedAt == nil)
    _ = apply(.askDoor(date(2026, 11, 17, 23, 1)), &s, date(2026, 11, 17, 23, 1))
    _ = apply(.cancelDoor, &s, date(2026, 11, 17, 23, 1))
    #expect(s.door == nil && s.doorAskedAt == nil)
    var opened = open(at: date(2026, 11, 17, 23))
    _ = apply(.askDoor(date(2026, 11, 17, 23, 2)), &opened, date(2026, 11, 17, 23, 2))
    _ = apply(.lockDoor, &opened, date(2026, 11, 17, 23, 2))
    #expect(opened.door == nil && opened.doorAskedAt == nil)
    _ = apply(.askDoor(nil), &opened, date(2026, 11, 17, 23, 3))
    #expect(opened.doorAskedAt == nil)
  }
}
