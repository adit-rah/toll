import Foundation
import Testing

@testable import TollCore

/// P-2 to P-4 (spec §11: trial night counting across reinstall). Nights are the Sleep block's.
struct TrialTests {
  let config = TollConfig.defaults
  let sleep = WeeklySchedule.everyDay(usual)

  func night(_ start: Date, _ now: Date) -> Int? {
    Trial.night(since: start, now: now, sleep: sleep, calendar: london, config: config)
  }

  @Test func sevenNightsFromSetup() {
    let start = date(2026, 11, 17, 15)
    #expect(night(start, start) == 1)
    #expect(night(start, date(2026, 11, 21, 23)) == 5)
    #expect(night(start, date(2026, 11, 23, 23)) == 7)
    #expect(night(start, date(2026, 11, 24, 7)) == nil)
  }

  @Test func setupInsideTheWindowCountsThatNightAsTheFirst() {
    let start = date(2026, 11, 17, 23, 30)
    #expect(night(start, start) == 1)
    #expect(night(start, date(2026, 11, 18, 7)) == 2)
  }

  @Test func afterTheTrialNoBlockTurnsOn() {
    var s = setUp()
    s.trial.start = date(2026, 11, 17, 15)
    s.places.append(libraryPlace)
    s.blocks.append(studyBlock())
    arrive(&s, libraryPlace, date(2026, 11, 24, 9))
    run(&s, date(2026, 11, 23, 23))
    #expect(s.isBlocking)
    run(&s, date(2026, 11, 24, 10))
    #expect(!s.trial.entitled)
    #expect(!s.isBlocking)
  }

  @Test func purchaseKeepsItOn() {
    var s = setUp()
    s.trial.start = date(2026, 11, 17, 15)
    _ = apply(.purchased(true), &s, date(2026, 12, 24, 20))
    run(&s, date(2026, 12, 24, 23))
    #expect(s.isBlocking)
  }

  @Test func aReinstallKeepsTheFirstStart() {
    var s = DuskState()
    _ = apply(.trialStart(date(2026, 11, 17, 15)), &s, date(2026, 11, 26, 20))
    _ = apply(
      .finishSetup(sleep: sleepBlock(), home: homePlace, trialStart: date(2026, 11, 26, 20)), &s,
      date(2026, 11, 26, 20))
    #expect(s.trial.start == date(2026, 11, 17, 15))
    arrive(&s, homePlace, date(2026, 11, 26, 20))
    run(&s, date(2026, 11, 26, 23))
    #expect(!s.trial.entitled)
  }

  @Test func summaryCountsNightsAndBlockScreenTaps() {
    func line(_ at: Date, _ cause: ReconcileCause, on: Bool, changed: Bool) -> Transition {
      Transition(
        at: at, cause: cause, blockOn: on, changed: changed, home: true, inWindow: true,
        entitled: true)
    }
    let log = [
      line(date(2026, 11, 17, 22, 30), .windowStart, on: true, changed: true),
      line(date(2026, 11, 17, 23), .blockScreen, on: true, changed: false),
      line(date(2026, 11, 18, 1), .left, on: false, changed: true),
      line(date(2026, 11, 18, 2), .arrived, on: true, changed: true),
      line(date(2026, 11, 18, 23), .arrived, on: true, changed: true),
      line(date(2026, 11, 18, 23, 5), .blockScreen, on: true, changed: false),
    ]
    let summary = TrialSummary(log: log, calendar: london)
    #expect(summary.nightsBlocked == 2)
    #expect(summary.blockScreens == 2)
  }
}
