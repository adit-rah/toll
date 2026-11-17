import Foundation
import Testing

@testable import TollCore

/// B-1 to B-5 against every kind of missed or odd event (spec §11).
struct ReconcileTests {
  let london = calendar("Europe/London")
  let home = HomePoint(latitude: 51.5, longitude: -0.12, radiusMeters: 150)

  func state(home isHome: Bool? = true, at: Date = date(2026, 11, 17, 20)) -> SleepState {
    var state = SleepState()
    state.settings = SleepSettings(window: usual, home: home)
    state.presence = isHome.map { Presence(isHome: $0, at: at) }
    return state
  }

  /// One boot, monotonic seconds equal to wall seconds unless a test moves the wall clock.
  func boot(_ wall: Date, shift: TimeInterval = 0, id: String = "boot") -> MonotonicInstant {
    MonotonicInstant(bootID: id, seconds: wall.timeIntervalSinceReferenceDate - shift)
  }

  @discardableResult
  func run(
    _ state: inout SleepState, _ wall: Date, _ cause: ReconcileCause = .foreground,
    monotonic: MonotonicInstant? = nil, calendar: Calendar? = nil
  ) -> Reconcile.Outcome {
    Reconcile.run(
      &state, wall: wall, monotonic: monotonic ?? boot(wall), calendar: calendar ?? london,
      cause: cause)
  }

  @Test func homeInWindowEntitledIsOn() {
    var s = state()
    let outcome = run(&s, date(2026, 11, 17, 22, 30), .windowStart)
    #expect(s.blockOn)
    #expect(s.blockEndsAt == date(2026, 11, 18, 7))
    #expect(outcome.transition?.changed == true)
    #expect(outcome.transition?.cause == .windowStart)
  }

  @Test(arguments: [
    (Bool?.some(false), true), (nil, true), (true, false),
  ])
  func anyMissingPartIsOff(home: Bool?, entitled: Bool) {
    var s = state(home: home)
    s.entitled = entitled
    run(&s, date(2026, 11, 17, 23))
    #expect(!s.blockOn)
  }

  @Test func arriveLeaveAndReturnMidWindow() {
    var s = state(home: false)
    run(&s, date(2026, 11, 17, 22, 30), .windowStart)
    #expect(!s.blockOn)
    s.presence = Presence(isHome: true, at: date(2026, 11, 17, 23))
    run(&s, date(2026, 11, 17, 23), .arrived)
    #expect(s.blockOn)
    s.presence = Presence(isHome: false, at: date(2026, 11, 18, 1))
    run(&s, date(2026, 11, 18, 1), .left)
    #expect(!s.blockOn)
    s.presence = Presence(isHome: true, at: date(2026, 11, 18, 2))
    run(&s, date(2026, 11, 18, 2), .arrived)
    #expect(s.blockOn)
  }

  @Test func missedWindowEndIsLiftedByTheNextWake() {
    var s = state()
    run(&s, date(2026, 11, 17, 23))
    #expect(s.blockOn)
    let outcome = run(&s, date(2026, 11, 18, 9, 40), .launch)
    #expect(!s.blockOn)
    #expect(outcome.transition?.blockOn == false)
  }

  @Test func restartMidWindowKeepsTheBlock() {
    var s = state()
    run(&s, date(2026, 11, 17, 23))
    run(&s, date(2026, 11, 18, 2), .launch, monotonic: boot(date(2026, 11, 18, 2), id: "next"))
    #expect(s.blockOn)
  }

  @Test func clockSetForwardDoesNotEndTheNight() {
    var s = state()
    let real = date(2026, 11, 17, 23)
    run(&s, real)
    let fake = date(2026, 11, 18, 7, 5)
    run(&s, fake, monotonic: boot(real.addingTimeInterval(60)))
    #expect(s.blockOn)
  }

  @Test func clockSetBackCannotHoldTheBlockPastTheMorning() {
    var s = state()
    run(&s, date(2026, 11, 17, 23))
    let realMorning = date(2026, 11, 18, 7, 5)
    run(&s, date(2026, 11, 18, 6, 0), monotonic: boot(realMorning))
    #expect(!s.blockOn)
  }

  @Test func clockSetBackAfterTheMorningDoesNotBlockAgain() {
    var s = state()
    run(&s, date(2026, 11, 18, 7, 5))
    run(&s, date(2026, 11, 18, 6, 55), monotonic: boot(date(2026, 11, 18, 7, 6)))
    #expect(!s.blockOn)
  }

  @Test func flyingWestAfterTheMorningDoesNotBlockAgain() {
    var s = state()
    run(&s, date(2026, 11, 18, 7, 5))
    let landed = date(2026, 11, 18, 12, 30)
    run(&s, landed, calendar: calendar("America/Los_Angeles"))
    #expect(!s.blockOn)
  }

  @Test func setupInsideTonightsWindowBlocksTonight() {
    var s = state()
    s.lastNightEnd = nil
    run(&s, date(2026, 11, 17, 23, 15), .edit)
    #expect(s.blockOn)
  }

  @Test func editDuringBlockWaitsUntilItTurnsOff() {
    var s = state()
    run(&s, date(2026, 11, 17, 23))
    let later = SleepSettings(window: SleepWindow(start: time(23, 30), end: time(8)), home: home)
    s.submit(later)
    #expect(s.pending == later)
    #expect(s.settings.window == usual)
    run(&s, date(2026, 11, 18, 1), .edit)
    #expect(s.blockOn)
    let outcome = run(&s, date(2026, 11, 18, 7), .windowEnd)
    #expect(!s.blockOn)
    #expect(s.settings == later)
    #expect(s.pending == nil)
    #expect(outcome.settingsChanged)
  }

  @Test func editOutsideBlockAppliesAtOnce() {
    var s = state()
    run(&s, date(2026, 11, 17, 15))
    let early = SleepSettings(window: SleepWindow(start: time(14), end: time(22)), home: home)
    s.submit(early)
    #expect(s.pending == nil)
    run(&s, date(2026, 11, 17, 15), .edit)
    #expect(s.blockOn)
  }

  @Test func movingHomeForgetsPresence() {
    var s = state()
    s.submit(
      SleepSettings(window: usual, home: HomePoint(latitude: 0, longitude: 0, radiusMeters: 150)))
    #expect(s.presence == nil)
    run(&s, date(2026, 11, 17, 23))
    #expect(!s.blockOn)
  }

  @Test func quietWakesWriteNoLineUnlessSomethingChanged() {
    var s = state()
    #expect(run(&s, date(2026, 11, 17, 15), .foreground).transition == nil)
    #expect(run(&s, date(2026, 11, 17, 15), .sweepStart).transition?.changed == false)
    #expect(run(&s, date(2026, 11, 17, 23), .foreground).transition?.changed == true)
  }

  @Test func withoutLocationTheWindowAloneDecides() {
    var s = state(home: false)
    s.homeCheck = .windowOnly
    run(&s, date(2026, 11, 17, 23), .permission)
    #expect(s.blockOn)
    run(&s, date(2026, 11, 18, 7), .windowEnd)
    #expect(!s.blockOn)
  }

  @Test func locationBackInUseNeedsHomeAgain() {
    var s = state(home: false)
    s.homeCheck = .windowOnly
    run(&s, date(2026, 11, 17, 23))
    s.homeCheck = .location
    run(&s, date(2026, 11, 17, 23, 5), .permission)
    #expect(!s.blockOn)
  }
}
