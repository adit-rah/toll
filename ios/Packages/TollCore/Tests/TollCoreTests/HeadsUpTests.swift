import Foundation
import Testing

@testable import TollCore

/// D68, #104: one heads-up 20 minutes before each night that will block, asked for after the first
/// night, and nothing else.
struct HeadsUpTests {
  let sleepID = BlockID("sleep")

  /// Set up on Monday evening with home set, bought unless a test says otherwise.
  func state(purchased: Bool = true, finished: Date = date(2026, 11, 16, 21)) -> DuskState {
    var state = setUp()
    state.setupFinishedAt = finished
    state.trial.start = finished
    state.trial.purchased = purchased
    return state
  }

  func schedule(
    _ state: DuskState, _ now: Date, screenTime: Bool = true,
    permission: NotificationPermission = .allowed
  ) -> [HeadsUp] {
    HeadsUp.schedule(
      state, screenTime: screenTime, permission: permission, now: now, calendar: london)
  }

  func snapshot(_ state: DuskState, _ now: Date, notifications: NotificationPermission)
    -> HomeSnapshot
  {
    HomeSnapshot(state: state, log: [], now: now, calendar: london, notifications: notifications)
  }

  func plain(_ text: String?) -> String? { text?.replacingOccurrences(of: "\u{202F}", with: " ") }

  // MARK: When

  @Test func twentyMinutesBeforeEachOfTheWeeksNights() {
    let ups = schedule(state(), date(2026, 11, 17, 15))
    #expect(ups.count == 7)
    #expect(ups.first?.at == date(2026, 11, 17, 22, 10))
    #expect(ups.first?.start == date(2026, 11, 17, 22, 30))
    #expect(ups.first?.end == date(2026, 11, 18, 7))
    #expect(ups.last?.at == date(2026, 11, 23, 22, 10))
  }

  @Test func itSaysNightAndTheNightsHours() {
    let first = schedule(state(), date(2026, 11, 17, 15)).first
    #expect(first?.title == "Night starts in 20 min")
    #expect(plain(first?.body) == "10:30 pm – 7:00 am")
  }

  @Test func neverLate() {
    let ups = schedule(state(), date(2026, 11, 17, 22, 15))
    #expect(ups.first?.at == date(2026, 11, 18, 22, 10))
    #expect(ups.count == 6)
  }

  @Test func duringANightTheNextIsTomorrows() {
    var s = state()
    run(&s, date(2026, 11, 17, 23))
    #expect(s.isBlocking)
    #expect(schedule(s, date(2026, 11, 17, 23)).first?.at == date(2026, 11, 18, 22, 10))
  }

  @Test func eachNightOnItsOwnHours() {
    var s = state()
    s.blocks[0].schedule = WeeklySchedule(rules: [
      .init(days: Weekday.schoolNights, window: usual),
      .init(days: Weekday.weekendNights, window: TimeWindow(start: time(23, 30), end: time(9, 30))),
    ])
    let ups = schedule(s, date(2026, 11, 20, 12))
    // Friday and Saturday start later.
    #expect(
      ups.map(\.at).prefix(3) == [
        date(2026, 11, 20, 23, 10), date(2026, 11, 21, 23, 10), date(2026, 11, 22, 22, 10),
      ])
  }

  // MARK: Hours that change

  @Test func newHoursMoveIt() {
    var s = state()
    #expect(
      apply(
        .saveBlock(sleepBlock(TimeWindow(start: time(23), end: time(7)))), &s,
        date(2026, 11, 17, 15)) == nil)
    #expect(schedule(s, date(2026, 11, 17, 15)).first?.at == date(2026, 11, 17, 22, 40))
  }

  @Test func anEditHeldDuringTheNightMovesTheNightsAfterIt() {
    var s = state()
    run(&s, date(2026, 11, 17, 23))
    let later = sleepBlock(TimeWindow(start: time(23), end: time(7)))
    #expect(apply(.saveBlock(later), &s, date(2026, 11, 17, 23, 30)) == nil)
    #expect(s.pending[sleepID] != nil)
    let ups = schedule(s, date(2026, 11, 17, 23, 30))
    #expect(ups.first?.at == date(2026, 11, 18, 22, 40))
    // Once it applies, the same plan.
    run(&s, date(2026, 11, 18, 7, 5))
    #expect(s.pending.isEmpty)
    #expect(schedule(s, date(2026, 11, 18, 7, 5)) == ups)
  }

  // MARK: Only before a night that will block

  @Test func theFreeNightsOnly() {
    let ups = schedule(
      state(purchased: false, finished: date(2026, 11, 9, 21)), date(2026, 11, 17, 15))
    // Night 8 ended this morning; nights 9 to 14 are left.
    #expect(ups.count == 6)
    #expect(ups.last?.start == date(2026, 11, 22, 22, 30))
  }

  @Test func noneOnceTheFreeNightsHaveEnded() {
    var s = state(purchased: false, finished: date(2026, 11, 1, 21))
    run(&s, date(2026, 11, 17, 15))
    #expect(!s.trial.entitled)
    #expect(schedule(s, date(2026, 11, 17, 15)).isEmpty)
    s.trial.purchased = true
    #expect(schedule(s, date(2026, 11, 17, 15)).count == 7)
  }

  @Test func noneWithScreenTimeOff() {
    #expect(schedule(state(), date(2026, 11, 17, 15), screenTime: false).isEmpty)
  }

  @Test func noneWhenTheNightsBlockIsOff() {
    var s = state()
    s.blocks[0].isOn = false
    #expect(schedule(s, date(2026, 11, 17, 15)).isEmpty)
  }

  @Test func noneBeforeSetup() {
    var s = state()
    s.setupFinishedAt = nil
    #expect(schedule(s, date(2026, 11, 17, 15)).isEmpty)
  }

  // MARK: The switch and iOS

  @Test(arguments: [NotificationPermission.notAsked, .denied])
  func noneUntilIOSAllowsIt(permission: NotificationPermission) {
    #expect(schedule(state(), date(2026, 11, 17, 15), permission: permission).isEmpty)
  }

  @Test func theSwitchTurnsItOffAndOn() {
    var s = state()
    #expect(s.headsUp)
    #expect(apply(.headsUp(false), &s, date(2026, 11, 17, 15)) == nil)
    #expect(schedule(s, date(2026, 11, 17, 15)).isEmpty)
    #expect(apply(.headsUp(true), &s, date(2026, 11, 17, 15)) == nil)
    #expect(schedule(s, date(2026, 11, 17, 15)).count == 7)
  }

  @Test func filesFromBeforeTheSwitchLoadWithItOn() throws {
    var json = try #require(
      try JSONSerialization.jsonObject(with: DuskStore.encoder.encode(state())) as? [String: Any])
    json["headsUp"] = nil
    let loaded = DuskStore.decode(try JSONSerialization.data(withJSONObject: json))
    #expect(loaded.headsUp)
    #expect(loaded.blocks.count == 1)
  }

  // MARK: Tonight's card

  @Test func theCardComesTheMorningAfterTheFirstNightUntilIOSIsAsked() {
    let s = state()
    #expect(snapshot(s, date(2026, 11, 16, 21, 30), notifications: .notAsked).card == nil)
    let morning = snapshot(s, date(2026, 11, 17, 7, 30), notifications: .notAsked)
    #expect(morning.card == .headsUp)
    #expect(morning.headsUp?.at == date(2026, 11, 17, 22, 10))
    #expect(snapshot(s, date(2026, 11, 17, 7, 30), notifications: .allowed).card == nil)
    #expect(snapshot(s, date(2026, 11, 17, 7, 30), notifications: .denied).card == nil)
  }

  @Test func homeGoesFirstThenTheHeadsUp() {
    var s = state()
    s.blocks[0].place = nil
    s.places = []
    #expect(snapshot(s, date(2026, 11, 17, 8), notifications: .notAsked).card == .home)
    #expect(apply(.dismissCard(.home), &s, date(2026, 11, 17, 8)) == nil)
    #expect(snapshot(s, date(2026, 11, 17, 8), notifications: .notAsked).card == .headsUp)
  }

  @Test func notNowPutsItAwayForGood() {
    var s = state()
    #expect(apply(.dismissCard(.headsUp), &s, date(2026, 11, 17, 8)) == nil)
    #expect(snapshot(s, date(2026, 11, 17, 8), notifications: .notAsked).card == nil)
    #expect(snapshot(s, date(2026, 11, 24, 8), notifications: .notAsked).card == nil)
    #expect(!s.dismissed(.home))
  }

  @Test func theCardIsQuietAtNightAndGivesWayToWarnings() {
    var s = state()
    run(&s, date(2026, 11, 17, 23))
    #expect(snapshot(s, date(2026, 11, 17, 23), notifications: .notAsked).card == nil)
    let off = HomeSnapshot(
      state: state(), log: [], now: date(2026, 11, 17, 15), calendar: london, screenTime: false,
      notifications: .notAsked)
    #expect(off.screenTimeOff)
    #expect(off.card == nil)
    var whileUsing = state()
    whileUsing.location = .scheduleOnly
    #expect(snapshot(whileUsing, date(2026, 11, 17, 15), notifications: .notAsked).card == nil)
  }

  @Test func noCardOnceTheFreeWeekIsOver() {
    var s = state(purchased: false, finished: date(2026, 11, 1, 21))
    run(&s, date(2026, 11, 17, 15))
    #expect(snapshot(s, date(2026, 11, 17, 15), notifications: .notAsked).card == nil)
  }
}
