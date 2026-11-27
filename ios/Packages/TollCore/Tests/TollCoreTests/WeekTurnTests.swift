import Foundation
import Testing

@testable import TollCore

/// #127: the monitor wakes just after noon every day, so Monday's judgement of the buffers moves
/// that night's lock and heads-up while Dusk stays closed. Every wake here is the monitor's.
struct WeekTurnTests {
  let config = TollConfig.defaults
  let turn = TimeWindow(start: time(12, 1), end: time(12, 16))

  /// Set up on Monday the 16th at 3 pm, 15 minutes before sleep growing to 60, bought, at home:
  /// the lock starts at 10:15 pm.
  func installed() -> DuskState {
    var state = setUp()
    #expect(
      apply(
        .finishSetup(
          sleep: sleepBlock(), home: homePlace, trialStart: date(2026, 11, 16, 15), fit: d76),
        &state, date(2026, 11, 16, 15)) == nil)
    state.trial.purchased = true
    state.screenTimeAllowed = true
    run(&state, date(2026, 11, 16, 15))
    return state
  }

  /// Monday the 16th to Friday the 20th, each night on at its lock and off at wake, by the
  /// monitor alone; `paused` nights ask for a pause inside the gap.
  func nights(_ state: inout DuskState, lock: (Int, Int), paused: Set<Int> = []) {
    for day in 16...20 {
      run(&state, date(2026, 11, day, lock.0, lock.1), .windowStart)
      if paused.contains(day) {
        #expect(apply(.startDoor, &state, date(2026, 11, day, lock.0, lock.1)) == nil)
        run(&state, date(2026, 11, day, lock.0, lock.1 + 1, 1), .doorStart)
        run(&state, date(2026, 11, day, lock.0, lock.1 + 12), .doorEnd)
      }
      run(&state, date(2026, 11, day + 1, 7), .windowEnd)
      run(&state, date(2026, 11, day + 1, 7, 1), .sweepStart)
    }
  }

  @Test func theTurnIsJustAfterNoonForThePlatformsMinimum() {
    #expect(config.gap.turnDelayMinutes == 1)
    #expect(WeekTurn.window(config) == turn)
    #expect(turn.isValid)
  }

  @Test func everyReconcileAsksForTheTurnWhileABufferGrows() {
    var state = installed()
    #expect(run(&state, date(2026, 11, 17, 9)).turn == turn)
    // A fixed buffer is never judged; with both fixed nothing needs the wake.
    #expect(apply(.gap(.fixed(30)), &state, date(2026, 11, 17, 9)) == nil)
    #expect(run(&state, date(2026, 11, 17, 9)).turn == nil)
    #expect(
      apply(.buffer(.after, .grows(15), target: nil), &state, date(2026, 11, 17, 9)) == nil)
    #expect(run(&state, date(2026, 11, 17, 9)).turn == turn)
  }

  @Test func noTurnBeforeSetup() {
    var state = setUp()
    #expect(run(&state, date(2026, 11, 16, 12, 1), .weekTurn).turn == nil)
  }

  @Test func aGrowthAtTheTurnLocksEarlierThatNight() {
    var state = installed()
    nights(&state, lock: (22, 15))
    let effects = run(&state, date(2026, 11, 23, 12, 1), .weekTurn)
    #expect(state.gap.minutes == 30)
    #expect(effects.windows == [TimeWindow(start: time(22), end: time(7))])
    #expect(effects.log?.cause == .weekTurn)
    run(&state, date(2026, 11, 23, 22), .windowStart)
    #expect(state.isBlocking)
  }

  @Test func anEaseAtTheTurnWaitsForTheLaterLock() {
    var state = installed()
    #expect(apply(.gap(.grows(30)), &state, date(2026, 11, 16, 16)) == nil)
    nights(&state, lock: (22, 0), paused: [17, 18])
    let effects = run(&state, date(2026, 11, 23, 12, 1), .weekTurn)
    #expect(state.gap.minutes == 15)
    #expect(effects.windows == [TimeWindow(start: time(22, 15), end: time(7))])
    run(&state, date(2026, 11, 23, 22), .foreground)
    #expect(!state.isBlocking)
  }

  @Test func otherDaysTurnsChangeNothing() {
    var state = installed()
    nights(&state, lock: (22, 15))
    let effects = run(&state, date(2026, 11, 21, 12, 1), .weekTurn)
    #expect(state.gap.minutes == 15)
    #expect(effects.windows == nil)
    #expect(effects.log?.changed == false)
  }

  // MARK: The heads-up

  @Test func theHeadsUpMovesWithMondaysChange() throws {
    var state = installed()
    nights(&state, lock: (22, 15))
    let now = date(2026, 11, 23, 12, 1)
    run(&state, now, .weekTurn)
    let plan = try #require(WeekTurn.headsUps(state, now: now, calendar: london))
    #expect(plan.first?.at == date(2026, 11, 23, 21, 40))
    #expect(plan.count == config.headsUp.nightsAhead)
  }

  @Test func noNewHeadsUpWithoutAChangeToday() {
    var state = installed()
    nights(&state, lock: (22, 15), paused: [17])
    run(&state, date(2026, 11, 23, 12, 1), .weekTurn)
    // One pause in the gap and five nights: smooth, so it grew. A hold wouldn't replan.
    #expect(state.gap.minutes == 30)
    // Tuesday's turn: the change is Monday's, already handed over.
    #expect(WeekTurn.headsUps(state, now: date(2026, 11, 24, 12, 1), calendar: london) == nil)

    var held = installed()
    run(&held, date(2026, 11, 23, 12, 1), .weekTurn)
    #expect(held.gap.change == nil)
    #expect(WeekTurn.headsUps(held, now: date(2026, 11, 23, 12, 1), calendar: london) == nil)
  }

  @Test func noHeadsUpWhenTheSwitchIsOff() {
    var state = installed()
    state.headsUp = false
    nights(&state, lock: (22, 15))
    run(&state, date(2026, 11, 23, 12, 1), .weekTurn)
    #expect(state.gap.minutes == 30)
    #expect(WeekTurn.headsUps(state, now: date(2026, 11, 23, 12, 1), calendar: london) == nil)
  }

  // MARK: Settings › How it works

  @Test func howItWorksSaysTheRuleWithTheConfigsNumbers() {
    let lines = Copy.Settings.howItWorksLines(config, in: london)
    #expect(lines.count == 5)
    #expect(
      lines[2]
        == "Apps lock a while before you fall asleep and stay locked a while after you wake. Set to grow with you, each can change every Monday at noon: 15 min longer after a week with few pauses in it, 15 min shorter after one with 2 or more."
    )
    #expect(
      lines[3]
        == "A pause opens blocked apps for 10 minutes, after a one-minute wait. You get 3 a week, back every Monday at noon."
    )
  }

  @Test func howItWorksFollowsTheConfig() {
    var other = config
    other.door.minutes = 5
    other.door.waitSeconds = 30
    other.unlocks.max = 2
    other.unlocks.refillWeekday = 1
    other.after.step = 10
    let lines = Copy.Settings.howItWorksLines(other, in: london)
    #expect(lines[2].contains("every Sunday at noon: a step longer"))
    #expect(
      lines[3]
        == "A pause opens blocked apps for 5 minutes, after a 30-second wait. You get 2 a week, back every Sunday at noon."
    )
  }
}
