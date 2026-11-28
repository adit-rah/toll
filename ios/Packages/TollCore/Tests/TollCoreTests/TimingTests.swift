import Foundation
import Testing

@testable import TollCore

/// Personal timing in the engine (D66, D99, #155): one start a week, Monday to Sunday by the
/// night's date, inside the buffer before sleep, never moving wake, and never changed while the
/// night is on.
struct TimingTests {
  /// Set up the week before, 10:30 pm to 7 am at home, 30 minutes before sleep, growing; timing
  /// and Health on. The lock is at 10 pm.
  static func timed(before: Gap = .growing(from: 30, to: 60)) -> DuskState {
    var state = setUp()
    state.setupFinishedAt = date(2026, 11, 16, 15)
    state.trial.start = date(2026, 11, 16, 15)
    state.gap = before
    state.health = true
    state.timing.on = true
    return state
  }

  static let earlier = Timing.Hold(start: "2026-11-23", offset: -30, prob: 0.4, settled: false)
  static let later = Timing.Hold(start: "2026-11-23", offset: 30, prob: 0.35, settled: false)

  /// Monday 23 November, 3 pm: the start drawn for the week and in force.
  static func held(_ hold: Timing.Hold = earlier, before: Gap = .growing(from: 30, to: 60))
    -> DuskState
  {
    var state = timed(before: before)
    let monday = date(2026, 11, 23, 15)
    run(&state, monday)
    #expect(apply(.hold(hold, generator: 42), &state, monday) == nil)
    run(&state, monday)
    return state
  }

  static func lockStart(_ state: DuskState) -> ClockTime? {
    state.lockSleep?.schedule.windows.first?.start
  }

  @Test func theStartStaysInsideTheBufferBeforeSleep() {
    let config = TollConfig.defaults
    #expect(Timing.allowed(before: 30, config: config) == [-30, 0, 30])
    #expect(Timing.allowed(before: 60, config: config) == [-30, 0, 30])
    // Never after bed.
    #expect(Timing.allowed(before: 15, config: config) == [-30, 0])
    #expect(Timing.allowed(before: 0, config: config) == [-30, 0])
    // D101: never earlier past 60.
    #expect(Timing.allowed(before: 75, config: config) == [0, 30])
    #expect(Timing.allowed(before: 90, config: config) == [0, 30])
  }

  @Test func weeksRunMondayToSundayByTheNightsDate() {
    #expect(Timing.week("2001-01-01") == 0)
    #expect(Timing.week("2001-01-07") == 0)
    #expect(Timing.week("2001-01-08") == 1)
    #expect(Timing.week("2000-12-31") == -1)
    #expect(Timing.week("2026-11-23") == Timing.week("2026-11-29"))
    #expect(Timing.week("2026-11-29") != Timing.week("2026-11-30"))
    #expect(Timing.week("23 November") == nil)
  }

  @Test func onlyAPersonWhoChoseItAndHealthIsAsked() {
    let monday = date(2026, 11, 23, 15)
    var state = Self.timed()
    let ask = TimingRules.ask(state, now: monday, calendar: london)
    #expect(ask?.night == "2026-11-23")
    #expect(ask?.allowed == [-30, 0, 30])
    #expect(ask?.weekend == false)
    #expect(ask?.generator == nil)
    state.health = false
    #expect(TimingRules.ask(state, now: monday, calendar: london) == nil)
    state.health = true
    state.timing.on = false
    #expect(TimingRules.ask(state, now: monday, calendar: london) == nil)
  }

  @Test func nothingIsDrawnCloseToTheLockOrWhileItsOn() {
    let state = Self.timed()
    #expect(TimingRules.ask(state, now: date(2026, 11, 23, 20, 29), calendar: london) != nil)
    #expect(TimingRules.ask(state, now: date(2026, 11, 23, 20, 31), calendar: london) == nil)
    #expect(TimingRules.ask(state, now: date(2026, 11, 23, 23), calendar: london) == nil)
    // The morning after: the next night is that evening's.
    #expect(
      TimingRules.ask(state, now: date(2026, 11, 24, 8), calendar: london)?.night == "2026-11-24")
  }

  @Test func theWeeksStartMovesTheLockAndNeverWake() {
    let plan = Self.timed()
    let state = Self.held()
    #expect(Self.lockStart(plan) == time(22))
    #expect(Self.lockStart(state) == time(21, 30))
    #expect(state.lead == 60)
    #expect(
      state.lockSleep?.schedule.windows.first?.end == plan.lockSleep?.schedule.windows.first?.end)
    #expect(Self.lockStart(Self.held(Self.later)) == time(22, 30))
    #expect(state.timing.generator == "42")
    // Nothing more to draw this week.
    #expect(TimingRules.ask(state, now: date(2026, 11, 25, 9), calendar: london) == nil)
  }

  @Test func theDeviceActivityScheduleMovesWithIt() {
    var state = Self.timed()
    let monday = date(2026, 11, 23, 15)
    run(&state, monday)
    _ = apply(.hold(Self.earlier, generator: 42), &state, monday)
    let effects = run(&state, monday)
    #expect(effects.windows?.contains { $0.start == time(21, 30) } == true)
  }

  @Test func aWeekHoldsOneStartMondayToSunday() {
    var state = Self.held()
    for day in 24...29 {
      run(&state, date(2026, 11, day, 15))
      #expect(Self.lockStart(state) == time(21, 30))
    }
    // Sunday's night is still the week's past midnight, while its lock is on.
    run(&state, date(2026, 11, 30, 2))
    #expect(Self.lockStart(state) == time(21, 30))
    // Once it ends, the next night is Monday's, the next week's: the plan, until the app draws.
    run(&state, date(2026, 11, 30, 9))
    #expect(Self.lockStart(state) == time(22))
    #expect(
      TimingRules.ask(state, now: date(2026, 11, 30, 9), calendar: london)?.night == "2026-11-30")
    #expect(state.timing.hold(forNight: date(2026, 11, 29, 0)) == Self.earlier)
    #expect(state.timing.hold(forNight: date(2026, 11, 30, 0)) == nil)
  }

  @Test func changingTheBufferPastWhatTheStartAllowsRedrawsThatNight() {
    var state = Self.held(before: .growing(from: 60, to: 60))
    #expect(Self.lockStart(state) == time(21))
    let wednesday = date(2026, 11, 25, 15)
    _ = apply(.buffer(.before, .fixed(75), target: nil), &state, wednesday)
    run(&state, wednesday)
    #expect(state.timing.inForce == nil)
    #expect(Self.lockStart(state) == time(21, 15))
    let ask = TimingRules.ask(state, now: wednesday, calendar: london)
    #expect(ask?.night == "2026-11-25")
    #expect(ask?.allowed == [0, 30])
    #expect(ask?.held == Self.earlier)
  }

  @Test func switchedOffTheLockGoesBackToThePlanBetweenNights() {
    var state = Self.held()
    let evening = date(2026, 11, 25, 21, 45)
    run(&state, evening)
    #expect(state.isBlocking)
    _ = apply(.timing(false), &state, evening)
    run(&state, evening)
    // The night that's on keeps its start.
    #expect(Self.lockStart(state) == time(21, 30))
    run(&state, date(2026, 11, 26, 9))
    #expect(Self.lockStart(state) == time(22))
    #expect(state.timing.hold(forNight: date(2026, 11, 25, 0)) == Self.earlier)
    #expect(state.timing.hold(forNight: date(2026, 11, 26, 0)) == nil)
  }

  @Test func anAnswerToAQuestionNoLongerAskedChangesNothing() {
    var state = Self.timed()
    let monday = date(2026, 11, 23, 15)
    run(&state, monday)
    var wrongNight = Self.earlier
    wrongNight.start = "2026-11-16"
    _ = apply(.hold(wrongNight, generator: 7), &state, monday)
    var notAllowed = Self.earlier
    notAllowed.offset = 45
    _ = apply(.hold(notAllowed, generator: 7), &state, monday)
    _ = apply(.hold(Self.earlier, generator: 7), &state, date(2026, 11, 23, 21))
    #expect(state.timing == Self.timed().timing)
  }

  /// The night's end lets a week's start go; the noon wake is the second chance if that wake was
  /// missed, so a later start never runs into Monday's night.
  @Test func theNoonWakeRunsWhileAStartIsHeld() {
    var plan = Self.timed()
    plan.gap.mode = .fixed
    #expect(WeekTurn.schedule(plan) == nil)
    var state = Self.held(Self.later)
    state.gap.mode = .fixed
    #expect(WeekTurn.schedule(state) == WeekTurn.window())
  }

  @Test func headsUpsFollowTheWeeksStartThenThePlan() {
    var state = Self.held()
    state.screenTimeAllowed = true
    state.trial.purchased = true
    let ups = HeadsUp.schedule(
      state, screenTime: true, permission: .allowed, now: date(2026, 11, 26, 15),
      calendar: london)
    #expect(ups.count == 7)
    let starts = ups.map { Copy.time($0.start, in: london) }
    #expect(starts.prefix(4).allSatisfy { $0 == Copy.time(date(2026, 11, 26, 21, 30), in: london) })
    #expect(starts.dropFirst(4).allSatisfy { $0 == Copy.time(date(2026, 11, 26, 22), in: london) })
  }

  @Test func tonightSaysTheLeadTheLockRunsWith() {
    let state = Self.held()
    let home = HomeSnapshot(
      state: state, log: [], now: date(2026, 11, 25, 15), calendar: london)
    #expect(home.beforeBed == Copy.Gap.beforeBed(60))
  }

  @Test func onlyAFileWithTimingInItNeedsThisBuildToWriteIt() {
    #expect(Self.timed().reader == 5)
    #expect(setUp().reader == DuskState.minReader)
  }
}
