import Foundation
import Testing

@testable import TollCore

/// B-1 to B-5 for the Sleep block, against every kind of missed or odd event (spec §11).
struct ReconcileTests {
  let sleepID = BlockID("sleep")

  @Test func homeInWindowEntitledIsOn() {
    var s = setUp()
    let effects = run(&s, date(2026, 11, 17, 22, 30), .windowStart)
    #expect(s.isBlocking)
    #expect(s.runtime.active[sleepID] == date(2026, 11, 18, 7))
    #expect(effects.log?.changed == true)
    #expect(effects.log?.cause == .windowStart)
    #expect(effects.shield.selections == [Data([1])])
  }

  @Test(arguments: [(Bool?.some(false), true), (nil, true), (true, false)])
  func anyMissingPartIsOff(home: Bool?, entitled: Bool) {
    var s = setUp(home: home)
    s.trial.start = entitled ? nil : date(2026, 10, 1, 12)
    let effects = run(&s, date(2026, 11, 17, 23))
    #expect(!s.isBlocking)
    #expect(effects.shield.isOff)
  }

  @Test func arriveLeaveAndReturnMidWindow() {
    var s = setUp(home: false)
    run(&s, date(2026, 11, 17, 22, 30), .windowStart)
    #expect(!s.isBlocking)
    arrive(&s, homePlace, date(2026, 11, 17, 23))
    run(&s, date(2026, 11, 17, 23), .arrived)
    #expect(s.isBlocking)
    arrive(&s, homePlace, date(2026, 11, 18, 1), inside: false)
    run(&s, date(2026, 11, 18, 1), .left)
    #expect(!s.isBlocking)
    arrive(&s, homePlace, date(2026, 11, 18, 2))
    run(&s, date(2026, 11, 18, 2), .arrived)
    #expect(s.isBlocking)
  }

  @Test func missedWindowEndIsLiftedByTheNextWake() {
    var s = setUp()
    run(&s, date(2026, 11, 17, 23))
    let effects = run(&s, date(2026, 11, 18, 9, 40), .launch)
    #expect(!s.isBlocking)
    #expect(effects.log?.blockOn == false)
  }

  @Test func restartMidWindowKeepsTheBlock() {
    var s = setUp()
    run(&s, date(2026, 11, 17, 23))
    run(&s, date(2026, 11, 18, 2), .launch, monotonic: boot(date(2026, 11, 18, 2), id: "next"))
    #expect(s.isBlocking)
  }

  @Test func clockSetForwardDoesNotEndTheNight() {
    var s = setUp()
    let real = date(2026, 11, 17, 23)
    run(&s, real)
    run(&s, date(2026, 11, 18, 7, 5), monotonic: boot(real.addingTimeInterval(60)))
    #expect(s.isBlocking)
  }

  @Test func clockSetBackCannotHoldTheBlockPastTheMorning() {
    var s = setUp()
    run(&s, date(2026, 11, 17, 23))
    run(&s, date(2026, 11, 18, 6), monotonic: boot(date(2026, 11, 18, 7, 5)))
    #expect(!s.isBlocking)
  }

  @Test func clockSetBackAfterTheMorningDoesNotBlockAgain() {
    var s = setUp()
    run(&s, date(2026, 11, 18, 7, 5))
    run(&s, date(2026, 11, 18, 6, 55), monotonic: boot(date(2026, 11, 18, 7, 6)))
    #expect(!s.isBlocking)
  }

  @Test func flyingWestAfterTheMorningDoesNotBlockAgain() {
    var s = setUp()
    run(&s, date(2026, 11, 18, 7, 5))
    run(&s, date(2026, 11, 18, 12, 30), calendar: calendar("America/Los_Angeles"))
    #expect(!s.isBlocking)
  }

  @Test func setupInsideTonightsWindowBlocksTonight() {
    var s = DuskState()
    #expect(
      apply(
        .finishSetup(sleep: sleepBlock(), home: homePlace, trialStart: date(2026, 11, 17, 23)), &s,
        date(2026, 11, 17, 23))
        == nil)
    arrive(&s, homePlace, date(2026, 11, 17, 23))
    run(&s, date(2026, 11, 17, 23, 15), .edit)
    #expect(s.isBlocking)
  }

  @Test func editDuringBlockWaitsUntilItEnds() {
    var s = setUp()
    run(&s, date(2026, 11, 17, 23))
    var later = sleepBlock(TimeWindow(start: time(23, 30), end: time(8)))
    later.name = "Sleep"
    #expect(apply(.saveBlock(later), &s, date(2026, 11, 17, 23)) == nil)
    #expect(s.pending[sleepID] == .saveEdit(later))
    #expect(s.sleepBlock?.schedule == .everyDay(usual))
    run(&s, date(2026, 11, 18, 1), .edit)
    #expect(s.isBlocking)
    run(&s, date(2026, 11, 18, 7), .windowEnd)
    #expect(!s.isBlocking)
    #expect(s.sleepBlock == later)
    #expect(s.pending.isEmpty)
  }

  @Test func editOutsideBlockAppliesAtOnce() {
    var s = setUp()
    run(&s, date(2026, 11, 17, 15))
    let early = sleepBlock(TimeWindow(start: time(14), end: time(22)))
    #expect(apply(.saveBlock(early), &s, date(2026, 11, 17, 15)) == nil)
    #expect(s.pending.isEmpty)
    run(&s, date(2026, 11, 17, 15), .edit)
    #expect(s.isBlocking)
  }

  @Test func movingHomeForgetsPresence() {
    var s = setUp()
    var moved = homePlace
    moved.latitude = 0
    #expect(apply(.savePlace(moved), &s, date(2026, 11, 17, 15)) == nil)
    #expect(s.presence[homePlace.id] == nil)
    run(&s, date(2026, 11, 17, 23))
    #expect(!s.isBlocking)
  }

  @Test func renamingHomeKeepsPresence() {
    var s = setUp()
    var renamed = homePlace
    renamed.name = "Flat"
    #expect(apply(.savePlace(renamed), &s, date(2026, 11, 17, 15)) == nil)
    #expect(s.presence[homePlace.id] != nil)
  }

  @Test func movingHomeDuringTheBlockWaits() {
    var s = setUp()
    run(&s, date(2026, 11, 17, 23))
    var moved = homePlace
    moved.latitude = 0
    #expect(apply(.savePlace(moved), &s, date(2026, 11, 17, 23)) == nil)
    #expect(s.place(homePlace.id) == homePlace)
    run(&s, date(2026, 11, 18, 7), .windowEnd)
    #expect(s.place(homePlace.id) == moved)
  }

  @Test func quietWakesWriteNoLineUnlessSomethingChanged() {
    var s = setUp()
    #expect(run(&s, date(2026, 11, 17, 15), .foreground).log == nil)
    #expect(run(&s, date(2026, 11, 17, 15), .sweepStart).log?.changed == false)
    #expect(run(&s, date(2026, 11, 17, 23), .foreground).log?.changed == true)
  }

  @Test func withoutLocationTheHoursAloneDecide() {
    var s = setUp(home: false)
    s.location = .scheduleOnly
    let effects = run(&s, date(2026, 11, 17, 23), .permission)
    #expect(s.isBlocking)
    #expect(effects.places.isEmpty)
    run(&s, date(2026, 11, 18, 7), .windowEnd)
    #expect(!s.isBlocking)
  }

  @Test func locationBackInUseNeedsHomeAgain() {
    var s = setUp(home: false)
    s.location = .scheduleOnly
    run(&s, date(2026, 11, 17, 23))
    s.location = .places
    run(&s, date(2026, 11, 17, 23, 5), .permission)
    #expect(!s.isBlocking)
  }

  @Test func windowsAreScheduledOnceUntilTheyChange() {
    var s = setUp()
    #expect(run(&s, date(2026, 11, 17, 15)).windows == [usual])
    #expect(run(&s, date(2026, 11, 17, 16)).windows == nil)
  }
}

extension DuskState.PendingEdit {
  static func saveEdit(_ block: Block) -> Self { .save(block) }
}
