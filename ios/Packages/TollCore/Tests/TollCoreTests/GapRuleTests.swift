import Foundation
import Testing

@testable import TollCore

/// D76: the lock starts a gap before bed, and the gap grows with smooth weeks. The weekly rule is
/// `datascience/sim/gap_rule.py`'s.
struct GapRuleTests {
  let config = TollConfig.defaults
  /// Mondays in November 2026, the pauses' week keys (D70).
  let monday = date(2026, 11, 16, 0)

  func week(_ n: Int) -> Date { london.date(byAdding: .day, value: 7 * n, to: monday) ?? monday }

  func tally(nights: Int = 0, pauses: Int = 0, off: Bool = false) -> Gap.Tally {
    var tally = Gap.Tally(week: monday)
    tally.nights = Set((0..<nights).map { monday.addingTimeInterval(Double($0) * 86_400) })
    tally.pausesInGap = pauses
    tally.screenTimeOff = off
    return tally
  }

  func growing(_ minutes: Int = 15) -> Gap {
    var gap = Gap.newInstall(config)
    gap.minutes = minutes
    return gap
  }

  /// Judges each tally in turn on the Mondays after `monday`, returning the gap after each.
  func judged(_ gap: inout Gap, _ weeks: [Gap.Tally]) -> [Int] {
    weeks.enumerated().map { index, tally in
      gap.minutes = gap.judge(tally, week: week(index + 1), calendar: london, config: config)
      return gap.minutes
    }
  }

  @Test func tunablesMatchD76() {
    // The start moved from 15 to 30 with #144; the rule is unchanged.
    #expect(config.gap.start == 30)
    #expect(config.gap.step == 15)
    #expect(config.gap.cap == 60)
    #expect(config.gap.manualMax == 90)
    #expect(config.gap.smoothMinNights == 4)
    #expect(config.gap.smoothMaxPauses == 1)
    #expect(config.gap.hardPauses == 2)
    #expect(config.gap.offFreezeWeeks == 2)
    #expect(config.gap.smoothAfterEase == 2)
    #expect(config.headsUp.leadMinutes == 20)
  }

  // MARK: The weekly rule

  @Test func verdicts() {
    #expect(Gap.verdict(tally(nights: 4, pauses: 1), config) == .smooth)
    #expect(Gap.verdict(tally(nights: 3), config) == .hold)
    #expect(Gap.verdict(tally(nights: 7, pauses: 2), config) == .hard)
    #expect(Gap.verdict(tally(nights: 7, off: true), config) == .screenTimeOff)
  }

  @Test func smoothWeeksGrowItToSixtyAndNoFurther() {
    var gap = growing()
    let smooth = tally(nights: 5)
    #expect(judged(&gap, Array(repeating: smooth, count: 5)) == [30, 45, 60, 60, 60])
  }

  @Test func aHardWeekEasesAndTwoSmoothWeeksAreNeededToGrowAgain() {
    var gap = growing(45)
    let smooth = tally(nights: 6)
    #expect(
      judged(&gap, [tally(nights: 6, pauses: 2), smooth, smooth, smooth]) == [30, 30, 45, 60])
  }

  @Test func aHoldBetweenSmoothWeeksAfterAnEaseStartsTheCountAgain() {
    var gap = growing(30)
    let smooth = tally(nights: 6)
    #expect(
      judged(&gap, [tally(pauses: 3), smooth, tally(nights: 2), smooth, smooth]) == [
        15, 15, 15, 15, 30,
      ])
  }

  @Test func screenTimeOffEasesAndFreezesGrowthForTwoMondays() {
    var gap = growing(30)
    let smooth = tally(nights: 7)
    // Off: 15. Two frozen Mondays, then the two smooth weeks an ease needs are already there.
    #expect(
      judged(&gap, [tally(nights: 7, off: true), smooth, smooth, smooth]) == [15, 15, 15, 30])
  }

  @Test func neverBelowZero() {
    var gap = growing(0)
    #expect(judged(&gap, [tally(pauses: 2)]) == [0])
  }

  @Test func aFixedGapNeverMoves() {
    var gap = Gap()
    gap.minutes = 30
    #expect(judged(&gap, [tally(nights: 7), tally(pauses: 3), tally(off: true)]) == [30, 30, 30])
  }

  // MARK: The lock's hours

  @Test func theLockStartsTheGapBeforeBedAndWakeNeverMoves() {
    let lock = WeeklySchedule.everyDay(usual).locking(15)
    #expect(lock.windows == [TimeWindow(start: time(22, 15), end: time(7))])
    #expect(WeeklySchedule.everyDay(usual).locking(0) == .everyDay(usual))
  }

  @Test func aLockBeforeMidnightStartsTheDayBefore() {
    let bed = WeeklySchedule(rules: [
      .init(days: [.monday], window: TimeWindow(start: time(0, 30), end: time(8)))
    ])
    let lock = bed.locking(60)
    #expect(lock.rules.first?.days == [.sunday])
    #expect(lock.rules.first?.window == TimeWindow(start: time(23, 30), end: time(8)))
    // Sunday 11:30 pm is inside Monday's night's lock.
    #expect(lock.occurrence(containing: date(2026, 11, 15, 23, 45), calendar: london) != nil)
  }

  // MARK: In the engine

  /// Set up on Monday the 16th at 3 pm, home set and at home, bought: a new install.
  func installed() -> DuskState {
    var state = setUp()
    #expect(
      apply(
        .finishSetup(
          sleep: sleepBlock(), home: homePlace, trialStart: date(2026, 11, 16, 15), fit: d76),
        &state, date(2026, 11, 16, 15)) == nil)
    state.trial.purchased = true
    run(&state, date(2026, 11, 16, 15))
    return state
  }

  /// Each night from `first` for `count` nights: on at 10:20 pm, ended at 7:01 am.
  func nights(_ state: inout DuskState, from first: Int, count: Int) {
    for day in first..<(first + count) {
      run(&state, date(2026, 11, day, 22, 20), .windowStart)
      run(&state, date(2026, 11, day + 1, 7, 1), .windowEnd)
    }
  }

  @Test func aNewInstallLocksFifteenMinutesBeforeBed() {
    var state = installed()
    #expect(state.gap.minutes == 15)
    #expect(state.gap.mode == .grows)
    run(&state, date(2026, 11, 16, 22, 14))
    #expect(!state.isBlocking)
    let effects = run(&state, date(2026, 11, 16, 22, 15))
    #expect(state.isBlocking)
    #expect(state.runtime.active[BlockID("sleep")] == date(2026, 11, 17, 7))
    #expect(effects.log?.inWindow == true)
    #expect(state.runtime.scheduledWindows == [TimeWindow(start: time(22, 15), end: time(7))])
  }

  @Test func mondayNoonJudgesTheWeek() {
    var state = installed()
    nights(&state, from: 16, count: 5)
    run(&state, date(2026, 11, 23, 11, 59))
    #expect(state.gap.minutes == 15)
    let effects = run(&state, date(2026, 11, 23, 12))
    #expect(state.gap.minutes == 30)
    #expect(state.gap.change == Gap.Change(week: date(2026, 11, 23, 0), from: 15, to: 30))
    // The DeviceActivity schedule moves with it, from tonight.
    #expect(effects.windows == [TimeWindow(start: time(22), end: time(7))])
    #expect(state.gap.tally == Gap.Tally(week: date(2026, 11, 23, 0)))
  }

  @Test func twoPausesInsideTheGapEaseIt() {
    var state = installed()
    state.gap.minutes = 30
    for day in 16...20 {
      run(&state, date(2026, 11, day, 22, 10), .windowStart)
      if [17, 18].contains(day) {
        #expect(apply(.startDoor, &state, date(2026, 11, day, 22, 10)) == nil)
        run(&state, date(2026, 11, day, 22, 11, 1))
        run(&state, date(2026, 11, day, 22, 22))
      }
      run(&state, date(2026, 11, day + 1, 7, 1), .windowEnd)
    }
    #expect(state.gap.tally.pausesInGap == 2)
    run(&state, date(2026, 11, 23, 12))
    #expect(state.gap.minutes == 15)
    #expect(state.gap.change?.grew == false)
  }

  @Test func aPauseAfterBedDoesNotCount() {
    var state = installed()
    run(&state, date(2026, 11, 16, 23))
    #expect(apply(.startDoor, &state, date(2026, 11, 16, 23)) == nil)
    run(&state, date(2026, 11, 16, 23, 1, 1))
    #expect(state.door?.phase == .open)
    #expect(state.gap.tally.pausesInGap == 0)
  }

  @Test func screenTimeSwitchedOffEasesAtMonday() {
    var state = installed()
    state.gap.minutes = 30
    nights(&state, from: 16, count: 5)
    #expect(apply(.screenTime(false), &state, date(2026, 11, 20, 9)) == nil)
    #expect(apply(.screenTime(true), &state, date(2026, 11, 20, 10)) == nil)
    run(&state, date(2026, 11, 23, 12))
    #expect(state.gap.minutes == 15)
    #expect(state.gap.frozenThrough == date(2026, 12, 7, 0))
  }

  @Test func weeksWithNothingReconciledHold() {
    var state = installed()
    nights(&state, from: 16, count: 5)
    // Nothing ran for two weeks: the first is judged smooth, the empty one after it holds.
    run(&state, date(2026, 11, 30, 13))
    #expect(state.gap.minutes == 30)
    #expect(state.gap.change == Gap.Change(week: date(2026, 11, 30, 0), from: 15, to: 30))
  }

  @Test func aChangeDuringTheNightAppliesWhenItEnds() {
    var state = installed()
    run(&state, date(2026, 11, 16, 23))
    #expect(apply(.gap(.fixed(45)), &state, date(2026, 11, 16, 23)) == nil)
    #expect(state.gap.minutes == 15)
    #expect(state.gap.pending == .fixed(45))
    #expect(state.gap.upcoming == 45)
    let effects = run(&state, date(2026, 11, 17, 7, 1))
    #expect(state.gap.minutes == 45)
    #expect(state.gap.mode == .fixed)
    #expect(state.gap.pending == nil)
    #expect(effects.windows == [TimeWindow(start: time(21, 45), end: time(7))])
  }

  @Test func aChangeOutsideTheNightAppliesAtOnce() {
    var state = installed()
    #expect(apply(.gap(.fixed(90)), &state, date(2026, 11, 17, 12)) == nil)
    let effects = run(&state, date(2026, 11, 17, 12))
    #expect(state.gap.minutes == 90)
    #expect(effects.windows == [TimeWindow(start: time(21), end: time(7))])
  }

  @Test func settingsHoldsTheGapInsideItsBounds() {
    var state = installed()
    #expect(apply(.gap(.fixed(120)), &state, date(2026, 11, 17, 12)) == nil)
    #expect(state.gap.minutes == 90)
    #expect(apply(.gap(.grows(90)), &state, date(2026, 11, 17, 12)) == nil)
    #expect(state.gap.minutes == 60)
    #expect(state.gap.mode == .grows)
    #expect(apply(.gap(.fixed(-5)), &state, date(2026, 11, 17, 12)) == nil)
    #expect(state.gap.minutes == 0)
  }

  @Test func keepGoesBackToLastWeeksGap() {
    var state = installed()
    nights(&state, from: 16, count: 5)
    run(&state, date(2026, 11, 23, 12))
    #expect(apply(.keepGap, &state, date(2026, 11, 23, 14)) == nil)
    #expect(state.gap.minutes == 15)
    #expect(state.gap.mode == .grows)
    #expect(state.gap.change?.seen == true)
  }
}
