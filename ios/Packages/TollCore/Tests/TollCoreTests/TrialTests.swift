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

  /// The free week's facts stand still after it: day 20 says what day 8 said (#48).
  @Test func theFreeWeekIsItsSevenNightsAndStaysPut() {
    var s = setUp()
    s.setupFinishedAt = date(2026, 11, 1, 15)
    s.trial.start = date(2026, 11, 1, 15)
    func line(_ at: Date, _ cause: ReconcileCause, door: Door.Phase? = nil) -> Transition {
      Transition(
        at: at, cause: cause, blockOn: true, changed: false, home: true, inWindow: true,
        entitled: true, door: door, active: [BlockID("sleep")])
    }
    var log: [Transition] = []
    for day in 1...7 where day != 4 {
      log.append(line(date(2026, 11, day, 22, 30), .windowStart))
    }
    log.append(line(date(2026, 11, 2, 23), .blockScreen))
    log.append(line(date(2026, 11, 2, 23, 1), .blockScreen))
    // One unlock kept on the 3rd; one locked again within the regret time on the 5th.
    log.append(line(date(2026, 11, 3, 23, 2), .doorStart, door: .open))
    log.append(line(date(2026, 11, 3, 23, 9), .doorEnd))
    log.append(line(date(2026, 11, 5, 23, 2), .doorStart, door: .open))
    log.append(line(date(2026, 11, 5, 23, 3), .doorLocked))
    // After the trial, nothing counts.
    log.append(line(date(2026, 11, 9, 23), .blockScreen))
    let day8 = FreeWeek(state: s, log: log, now: date(2026, 11, 8, 15), calendar: london)
    let day20 = FreeWeek(state: s, log: log, now: date(2026, 11, 20, 15), calendar: london)
    #expect(day8 == day20)
    #expect(day8?.bars.count == 7)
    #expect(day8?.nightsBlocked == 6)
    #expect(day8?.nightsCounted == 7)
    #expect(day8?.timesStopped == 2)
    #expect(day8?.unlocksUsed == 1)
  }

  /// A reinstall after the free week isn't promised another (#46, P-4).
  @Test func setupOffersWhatThisPhoneHasLeft() {
    let sleep = WeeklySchedule.everyDay(usual)
    let now = date(2026, 11, 20, 15)
    func offer(_ start: Date?, purchased: Bool = false) -> Trial.Offer {
      Trial.offer(
        start: start, purchased: purchased, now: now, sleep: sleep, calendar: london,
        config: .defaults)
    }
    #expect(offer(nil) == .fresh(endsAt: date(2026, 11, 27, 7)))
    #expect(offer(date(2026, 11, 18, 15)) == .running(endsAt: date(2026, 11, 25, 7)))
    #expect(offer(date(2026, 11, 5, 15)) == .used(endedAt: date(2026, 11, 12, 7)))
    #expect(offer(date(2026, 11, 5, 15), purchased: true) == .purchased)
  }
}
