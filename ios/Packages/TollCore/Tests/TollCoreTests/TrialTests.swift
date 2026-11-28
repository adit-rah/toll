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

  @Test func fourteenNightsFromSetup() {
    let start = date(2026, 11, 17, 15)
    #expect(night(start, start) == 1)
    #expect(night(start, date(2026, 11, 21, 23)) == 5)
    #expect(night(start, date(2026, 11, 24, 7)) == 8)
    #expect(night(start, date(2026, 11, 30, 23)) == 14)
    #expect(night(start, date(2026, 12, 1, 7)) == nil)
  }

  /// D78: entitled through the 14th night, not the morning after it.
  @Test func fourteenNightsAreEntitled() {
    var s = setUp()
    s.trial.start = date(2026, 11, 17, 15)
    run(&s, date(2026, 11, 24, 23))
    #expect(s.trial.entitled)
    #expect(s.isBlocking)
    run(&s, date(2026, 11, 30, 23))
    #expect(s.trial.entitled)
    #expect(s.isBlocking)
    run(&s, date(2026, 12, 1, 7, 30))
    #expect(!s.trial.entitled)
  }

  /// A Sleep block on one night a week still reaches its fourteenth night.
  @Test func oneNightAWeekStillEnds() {
    let mondays = WeeklySchedule(rules: [.init(days: [.monday], window: usual)])
    #expect(
      Trial.lastEnd(
        since: date(2026, 11, 17, 15), sleep: mondays, calendar: london, config: config)
        == date(2027, 2, 23, 7))
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
    arrive(&s, libraryPlace, date(2026, 12, 1, 9))
    run(&s, date(2026, 11, 30, 23))
    #expect(s.isBlocking)
    run(&s, date(2026, 12, 1, 10))
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
    _ = apply(.trialStart(date(2026, 11, 17, 15)), &s, date(2026, 12, 3, 20))
    _ = apply(
      .finishSetup(sleep: sleepBlock(), home: homePlace, trialStart: date(2026, 12, 3, 20)), &s,
      date(2026, 12, 3, 20))
    #expect(s.trial.start == date(2026, 11, 17, 15))
    arrive(&s, homePlace, date(2026, 12, 3, 20))
    run(&s, date(2026, 12, 3, 23))
    #expect(!s.trial.entitled)
  }

  /// The free nights' facts stand still after them: day 27 says what day 15 said (#48).
  @Test func theFreeNightsAreFourteenAndStayPut() {
    var s = setUp()
    s.setupFinishedAt = date(2026, 11, 1, 15)
    s.trial.start = date(2026, 11, 1, 15)
    func line(_ at: Date, _ cause: ReconcileCause, door: Door.Phase? = nil) -> Transition {
      Transition(
        at: at, cause: cause, blockOn: true, changed: false, home: true, inWindow: true,
        entitled: true, door: door, active: [BlockID("sleep")])
    }
    var log: [Transition] = []
    for day in 1...14 where day != 4 {
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
    log.append(line(date(2026, 11, 16, 23), .blockScreen))
    let day15 = FreeNights(state: s, log: log, now: date(2026, 11, 15, 15), calendar: london)
    let day27 = FreeNights(state: s, log: log, now: date(2026, 11, 27, 15), calendar: london)
    #expect(day15 == day27)
    #expect(day15?.bars.count == 14)
    #expect(day15?.nightsBlocked == 13)
    #expect(day15?.nightsCounted == 14)
    #expect(day15?.timesStopped == 2)
    #expect(day15?.unlocksUsed == 1)
  }

  /// A reinstall after the free nights isn't promised another (#46, P-4).
  @Test func setupOffersWhatThisPhoneHasLeft() {
    let sleep = WeeklySchedule.everyDay(usual)
    let now = date(2026, 11, 20, 15)
    func offer(_ start: Date?, purchased: Bool = false) -> Trial.Offer {
      Trial.offer(
        start: start, purchased: purchased, now: now, sleep: sleep, calendar: london,
        config: .defaults)
    }
    #expect(offer(nil) == .fresh(endsAt: date(2026, 12, 4, 7)))
    #expect(offer(date(2026, 11, 18, 15)) == .running(endsAt: date(2026, 12, 2, 7)))
    #expect(offer(date(2026, 11, 5, 15)) == .used(endedAt: date(2026, 11, 19, 7)))
    #expect(offer(date(2026, 11, 5, 15), purchased: true) == .purchased)
  }

  // MARK: The start in two places (D78)

  /// A new phone on the same Apple ID: its own copy is later, or missing; the iCloud one wins.
  @Test func theEarliestStartWins() {
    let first = date(2026, 11, 3, 21)
    let later = date(2026, 11, 20, 21)
    let both = TrialStart(thisPhone: later, appleID: first)
    #expect(both.start == first)
    #expect(both.settled == TrialStart(thisPhone: first, appleID: first))
    #expect(TrialStart(thisPhone: first, appleID: later).start == first)
    #expect(
      TrialStart(thisPhone: nil, appleID: first).begun(now: later)
        == TrialStart(thisPhone: first, appleID: first))
  }

  /// iCloud Keychain off, or a phone that began before D78: this phone's start stands, as before.
  @Test func aStartOnThisPhoneOnly() {
    let start = date(2026, 11, 17, 15)
    let local = TrialStart(thisPhone: start, appleID: nil)
    #expect(local.start == start)
    #expect(local.settled == TrialStart(thisPhone: start, appleID: start))
    #expect(local.begun(now: date(2026, 11, 26, 20)).start == start)
    let none = TrialStart(thisPhone: nil, appleID: nil)
    #expect(none.start == nil)
    #expect(none.settled == none)
    #expect(none.begun(now: start) == TrialStart(thisPhone: start, appleID: start))
  }

  // MARK: A copy that can't be read (#140 risk 5)

  /// Corrupt, or a format from a build that broke the rule: on main it read as no start, so setup
  /// granted the free nights again from now, and `settle` wrote over it.
  @Test func anUnreadableCopyNeverGrantsNewFreeNights() {
    let written = date(2026, 11, 3, 21)
    let now = date(2026, 11, 26, 20)
    let unreadable = TrialStart(thisPhone: .unreadable(writtenAt: written), appleID: .none)
    #expect(unreadable.start == written)
    #expect(unreadable.begun(now: now).start == written)
    let offer = Trial.offer(
      start: unreadable.begun(now: now).start, purchased: false, now: now,
      sleep: .everyDay(usual), calendar: london, config: .defaults)
    #expect(offer == .used(endedAt: date(2026, 11, 17, 7)))
  }

  @Test func anUnreadableCopyIsNeverWrittenOver() {
    let start = date(2026, 11, 17, 15)
    let written = date(2026, 11, 20, 9)
    let mixed = TrialStart(thisPhone: .date(start), appleID: .unreadable(writtenAt: written))
    #expect(mixed.start == start)
    #expect(mixed.settled == mixed)
    #expect(mixed.begun(now: date(2026, 11, 26, 20)) == mixed)
    let later = TrialStart(thisPhone: .none, appleID: .unreadable(writtenAt: written))
    #expect(
      later.settled
        == TrialStart(thisPhone: .date(written), appleID: .unreadable(writtenAt: written)))
  }

  /// The Keychain answering "locked" or "busy" is not "no start": nothing is written that pass, so
  /// the iCloud copy's earlier start from another phone is never replaced.
  @Test func anUnknownCopyWritesNothing() {
    let first = date(2026, 11, 3, 21)
    let later = date(2026, 11, 20, 21)
    let unsure = TrialStart(thisPhone: .date(later), appleID: .unknown)
    #expect(!unsure.known)
    #expect(unsure.start == later)
    #expect(unsure.settled == unsure)
    #expect(unsure.begun(now: date(2026, 11, 26, 20)) == unsure)
    let back = TrialStart(thisPhone: .date(later), appleID: .date(first))
    #expect(back.settled == TrialStart(thisPhone: first, appleID: first))
  }

  /// The iCloud copy can arrive after setup on a new phone: the state takes the earlier start, and
  /// the free nights end when they would have on the first phone.
  @Test func anEarlierStartArrivingLaterEndsTheFreeNights() {
    var s = DuskState()
    _ = apply(
      .finishSetup(sleep: sleepBlock(), home: homePlace, trialStart: date(2026, 12, 3, 20)), &s,
      date(2026, 12, 3, 20))
    arrive(&s, homePlace, date(2026, 12, 3, 20))
    run(&s, date(2026, 12, 3, 23))
    #expect(s.trial.entitled)
    _ = apply(.trialStart(date(2026, 11, 17, 15)), &s, date(2026, 12, 4, 20))
    run(&s, date(2026, 12, 4, 23))
    #expect(s.trial.start == date(2026, 11, 17, 15))
    #expect(!s.trial.entitled)
  }
}
