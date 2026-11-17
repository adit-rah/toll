import Foundation
import Testing

@testable import TollCore

/// P-2 to P-4 (spec §11: trial night counting across reinstall).
struct TrialTests {
  let london = calendar("Europe/London")
  let config = TollConfig.defaults

  func state(trialStart: Date) -> SleepState {
    var state = SleepState()
    state.settings.window = usual
    state.presence = Presence(isHome: true, at: trialStart)
    state.trialStart = trialStart
    return state
  }

  func run(_ state: inout SleepState, _ now: Date) {
    Reconcile.run(
      &state, wall: now, monotonic: nil, calendar: london, cause: .foreground, config: config)
  }

  @Test func sevenNightsFromSetup() {
    let start = date(2026, 11, 17, 15)
    #expect(
      Trial.night(since: start, now: start, window: usual, calendar: london, config: config) == 1)
    let fifth = date(2026, 11, 21, 23)
    #expect(
      Trial.night(since: start, now: fifth, window: usual, calendar: london, config: config) == 5)
    let lastNight = date(2026, 11, 23, 23)
    #expect(
      Trial.night(since: start, now: lastNight, window: usual, calendar: london, config: config)
        == 7)
    let after = date(2026, 11, 24, 7)
    #expect(
      Trial.night(since: start, now: after, window: usual, calendar: london, config: config) == nil)
  }

  @Test func setupInsideTheWindowCountsThatNightAsTheFirst() {
    let start = date(2026, 11, 17, 23, 30)
    #expect(
      Trial.night(since: start, now: start, window: usual, calendar: london, config: config) == 1)
    let morning = date(2026, 11, 18, 7)
    #expect(
      Trial.night(since: start, now: morning, window: usual, calendar: london, config: config) == 2)
  }

  @Test func afterTheTrialTheBlockDoesNotTurnOn() {
    var s = state(trialStart: date(2026, 11, 17, 15))
    run(&s, date(2026, 11, 23, 23))
    #expect(s.blockOn)
    run(&s, date(2026, 11, 24, 23))
    #expect(!s.entitled)
    #expect(!s.blockOn)
  }

  @Test func purchaseKeepsItOn() {
    var s = state(trialStart: date(2026, 11, 17, 15))
    s.purchased = true
    run(&s, date(2026, 12, 24, 23))
    #expect(s.blockOn)
  }

  @Test func aReinstallKeepsTheFirstStart() {
    var reinstalled = SleepState()
    reinstalled.settings.window = usual
    reinstalled.presence = Presence(isHome: true, at: date(2026, 11, 26, 20))
    reinstalled.trialStart = date(2026, 11, 17, 15)
    run(&reinstalled, date(2026, 11, 26, 23))
    #expect(!reinstalled.entitled)
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
