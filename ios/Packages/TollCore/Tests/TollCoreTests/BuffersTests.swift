import Foundation
import SleepModel
import Testing

@testable import TollCore

/// #144: the night is the buffer before sleep, sleep, and the buffer after. Both buffers grow by
/// D76's weekly rule toward their own targets; a pause counts against the side it was asked in.
struct BuffersTests {
  let config = TollConfig.defaults

  func plain(_ text: String) -> String { text.replacingOccurrences(of: "\u{202F}", with: " ") }

  /// Asleep 11 pm to 7 am; 15 minutes before, growing to 60; 10 after, growing to 30.
  let fit = Fit(
    sleep: nil, before: .init(start: 15, target: 60), after: .init(start: 10, target: 30),
    health: true)

  /// Set up on Monday the 16th at 3 pm with that fit, home set and at home, bought.
  func installed() -> DuskState {
    var state = setUp()
    let sleep = sleepBlock(TimeWindow(start: time(23), end: time(7)))
    #expect(
      apply(
        .finishSetup(sleep: sleep, home: homePlace, trialStart: date(2026, 11, 16, 15), fit: fit),
        &state, date(2026, 11, 16, 15)) == nil)
    state.trial.purchased = true
    run(&state, date(2026, 11, 16, 15))
    return state
  }

  @Test func theLockIsBeforeSleepAndAfter() {
    let lock = WeeklySchedule.everyDay(usual).locking(before: 60, after: 30)
    #expect(lock.windows == [TimeWindow(start: time(21, 30), end: time(7, 30))])
    #expect(WeeklySchedule.everyDay(usual).locking(before: 0, after: 0) == .everyDay(usual))
    // A day holds at most 24 hours less DeviceActivity's 15 minutes; the side before keeps its own.
    let long = WeeklySchedule.everyDay(TimeWindow(start: time(20), end: time(19)))
    #expect(long.locking(before: 30, after: 30).windows.first?.minutes == 1425)
    #expect(long.locking(before: 30, after: 30).windows.first?.start == time(19, 30))
  }

  @Test func aFittedInstallLocksAroundSleep() {
    var state = installed()
    let numbers: [Int] = [
      state.gap.minutes, state.gap.target, state.after.minutes, state.after.target,
    ]
    #expect(numbers == [15, 60, 10, 30])
    #expect(state.gap.mode == .grows)
    #expect(state.after.mode == .grows)
    #expect(state.health)
    #expect(state.runtime.scheduledWindows == [TimeWindow(start: time(22, 45), end: time(7, 10))])
    run(&state, date(2026, 11, 16, 22, 45))
    #expect(state.isBlocking)
    #expect(state.runtime.active[BlockID("sleep")] == date(2026, 11, 17, 7, 10))
    run(&state, date(2026, 11, 17, 7, 5))
    #expect(state.isBlocking)
    run(&state, date(2026, 11, 17, 7, 10))
    #expect(!state.isBlocking)
  }

  @Test func setupWithoutAFitKeepsD76() {
    var state = setUp()
    #expect(
      apply(
        .finishSetup(sleep: sleepBlock(), home: homePlace, trialStart: date(2026, 11, 16, 15)),
        &state, date(2026, 11, 16, 15)) == nil)
    #expect(state.gap == .newInstall())
    #expect(state.after.minutes == 0)
    #expect(!state.after.offered)
  }

  /// Each night from `first` for `count`: on at the lock, off after it.
  func nights(_ state: inout DuskState, from first: Int, count: Int) {
    for day in first..<(first + count) {
      run(&state, date(2026, 11, day, 22, 50), .windowStart)
      run(&state, date(2026, 11, day + 1, 7, 40), .windowEnd)
    }
  }

  @Test func bothSidesGrowTowardTheirOwnTargets() {
    var state = installed()
    var seen: [(Int, Int)] = []
    for week in 0..<5 {
      nights(&state, from: 16 + 7 * week, count: 5)
      run(&state, london.date(byAdding: .day, value: 7 * (week + 1), to: date(2026, 11, 16, 12))!)
      seen.append((state.gap.minutes, state.after.minutes))
    }
    #expect(seen.map(\.0) == [30, 45, 60, 60, 60])
    #expect(seen.map(\.1) == [25, 30, 30, 30, 30])
    #expect(state.gap.change?.from == 45)
  }

  @Test func aPauseCountsAgainstTheSideItWasAskedIn() {
    var state = installed()
    // After waking: 7:02 am, inside the 10 minutes after 7.
    run(&state, date(2026, 11, 17, 7, 2))
    #expect(apply(.startDoor, &state, date(2026, 11, 17, 7, 2)) == nil)
    run(&state, date(2026, 11, 17, 7, 3, 1))
    #expect(state.after.tally.pausesInGap == 1)
    #expect(state.gap.tally.pausesInGap == 0)
    // Asleep: counts against nobody.
    run(&state, date(2026, 11, 17, 23, 30))
    #expect(apply(.startDoor, &state, date(2026, 11, 17, 23, 30)) == nil)
    run(&state, date(2026, 11, 17, 23, 31, 1))
    #expect(state.after.tally.pausesInGap == 1)
    #expect(state.gap.tally.pausesInGap == 0)
  }

  @Test func twoPausesAfterWakingEaseOnlyThatSide() {
    var state = installed()
    state.after.minutes = 30
    for day in 16...20 {
      run(&state, date(2026, 11, day, 22, 50), .windowStart)
      if [17, 18].contains(day) {
        run(&state, date(2026, 11, day + 1, 7, 5))
        #expect(apply(.startDoor, &state, date(2026, 11, day + 1, 7, 5)) == nil)
        run(&state, date(2026, 11, day + 1, 7, 6, 1))
      }
      run(&state, date(2026, 11, day + 1, 7, 40), .windowEnd)
    }
    run(&state, date(2026, 11, 23, 12))
    #expect(state.after.minutes == 15)
    #expect(state.gap.minutes == 30)
    // Monday's card names the side before sleep first; answering it answers both.
    #expect(GapRules.changed(state) == .before)
    #expect(apply(.dismissCard(.gapWeek), &state, date(2026, 11, 23, 14)) == nil)
    #expect(GapRules.changed(state) == nil)
  }

  @Test func settingsChangesOneSideAndItsTarget() {
    var state = installed()
    #expect(
      apply(.buffer(.after, .grows(20), target: 45), &state, date(2026, 11, 17, 12)) == nil)
    #expect(state.after.minutes == 20)
    #expect(state.after.target == 45)
    #expect(apply(.buffer(.after, .fixed(90), target: nil), &state, date(2026, 11, 17, 12)) == nil)
    #expect(state.after.minutes == config.after.manualMax)
    #expect(state.after.mode == .fixed)
    // A growing buffer never starts past its target.
    #expect(
      apply(.buffer(.before, .grows(80), target: 60), &state, date(2026, 11, 17, 12)) == nil)
    #expect(state.gap.minutes == 60)
  }

  @Test func aFitDuringTheNightWaitsForItsEnd() {
    var state = installed()
    run(&state, date(2026, 11, 16, 23, 30))
    let later = Fit(
      sleep: .everyDay(TimeWindow(start: time(23, 30), end: time(7, 30))),
      before: .init(start: 30, target: 75), after: .init(start: 20, target: 30), health: false)
    #expect(apply(.fit(later), &state, date(2026, 11, 16, 23, 30)) == nil)
    #expect(state.after.minutes == 10)
    #expect(state.after.pending == .grows(20))
    #expect(state.gap.target == 75)
    #expect(state.pending[BlockID("sleep")] != nil)
    run(&state, date(2026, 11, 17, 7, 11))
    #expect(state.sleepBlock?.schedule == later.sleep)
    #expect(state.gap.minutes == 30)
    #expect(state.after.minutes == 20)
    #expect(!state.health)
  }

  @Test func settingsSaysTheHoursAndBothSides() {
    var state = installed()
    #expect(plain(BeforeBed.sleepRow(state)) == "11 pm – 7 am · 15 min before · 10 min after")
    let after = BeforeBed(state: state, side: .after)
    #expect(after.grows)
    #expect(after.target == 30)
    #expect(plain(after.detail) == "Grows with you · now 10 min · next 25")
    run(&state, date(2026, 11, 16, 23, 30))
    #expect(
      apply(.buffer(.after, .fixed(20), target: nil), &state, date(2026, 11, 16, 23, 30)) == nil)
    #expect(plain(BeforeBed.sleepRow(state)) == "11 pm – 7 am · 15 min before · 20 min after")
    #expect(BeforeBed(state: state, side: .after).held)
  }

  @Test func theHeadsUpComesBeforeTheLock() {
    let state = installed()
    let first = HeadsUp.nights(
      state, screenTime: true, now: date(2026, 11, 16, 15), calendar: london
    ).first
    #expect(first?.at == date(2026, 11, 16, 22, 25))
  }
}
