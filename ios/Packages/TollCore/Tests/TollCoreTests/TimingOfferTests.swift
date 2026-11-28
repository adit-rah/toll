import Foundation
import Testing

@testable import TollCore

/// Personal timing offered (D65, #171): once, after the first week, only with Health chosen, at a
/// calm moment; Tonight says why when a week's start isn't the person's own; Settings › Sleep has
/// its switch, which needs Health.
struct TimingOfferTests {
  /// Set up on Monday 16 November at 3 pm, the night 10:30 pm to 7 am, with Health chosen.
  static var withHealth: DuskState {
    var state = setUp()
    state.setupFinishedAt = date(2026, 11, 16, 15)
    state.trial.start = date(2026, 11, 16, 15)
    state.health = true
    return state
  }

  func due(_ state: DuskState, _ now: Date) -> String? {
    Flows.due(state, now: now, calendar: london)?.id
  }

  @Test func offeredOnceTheFirstWeekHasEnded() {
    let state = Self.withHealth
    // Six nights have ended by Sunday afternoon; the seventh ends on Monday morning.
    #expect(Flows.nightsEnded(state, now: date(2026, 11, 22, 15), calendar: london) == 6)
    #expect(due(state, date(2026, 11, 22, 15)) == nil)
    #expect(due(state, date(2026, 11, 23, 15)) == Flows.timing.id)
  }

  @Test func onlyWithHealthChosen() {
    var state = Self.withHealth
    state.health = false
    #expect(due(state, date(2026, 11, 24, 15)) == nil)
  }

  @Test func onlyAtACalmMoment() {
    let state = Self.withHealth
    #expect(due(state, date(2026, 11, 23, 23)) == nil)
    // The band's hour before the lock.
    #expect(due(state, date(2026, 11, 23, 21, 45)) == nil)
    #expect(due(state, date(2026, 11, 24, 8, 10)) == Flows.timing.id)
  }

  @Test func notForSomeoneWhoAlreadyTurnedItOn() {
    var state = Self.withHealth
    #expect(apply(.timing(true), &state, date(2026, 11, 20, 15)) == nil)
    #expect(due(state, date(2026, 11, 24, 15)) == nil)
  }

  /// Fit Dusk to your sleep comes first for someone from before #144; this waits for another day.
  @Test func theFitComesFirst() {
    var state = Self.withHealth
    state.after.offered = true
    #expect(due(state, date(2026, 11, 24, 15)) == Flows.fitSleep.id)
    _ = Flows.record(
      Flows.fitSleep.id, version: 1, .answered, in: &state, now: date(2026, 11, 24, 15))
    state.after.offered = false
    #expect(due(state, date(2026, 11, 24, 16)) == nil)
    #expect(due(state, date(2026, 11, 25, 15)) == Flows.timing.id)
  }

  @Test func turningItOnAnswersItForGood() {
    var state = Self.withHealth
    let at = date(2026, 11, 24, 15)
    #expect(apply(.timing(true), &state, at) == nil)
    #expect(apply(.flow(id: Flows.timing.id, version: 1, .answered), &state, at) == nil)
    #expect(state.timing.on)
    // Turned off later in Settings, it isn't offered again.
    #expect(apply(.timing(false), &state, date(2026, 11, 26, 15)) == nil)
    #expect(due(state, date(2026, 11, 27, 15)) == nil)
  }

  @Test func keepingTheirOwnTimeAnswersItAndChangesNothing() {
    var state = Self.withHealth
    #expect(
      apply(.flow(id: Flows.timing.id, version: 1, .answered), &state, date(2026, 11, 24, 15))
        == nil)
    #expect(!state.timing.on)
    #expect(due(state, date(2026, 11, 25, 15)) == nil)
  }

  @Test func putOffForGoodItStaysOff() {
    var state = Self.withHealth
    let offers = TollConfig.defaults.flows.offers
    var defaults: [Command] = []
    for day in 0..<offers {
      let at = date(2026, 11, 24 + day, 15)
      #expect(due(state, at) == Flows.timing.id)
      defaults = Flows.record(Flows.timing.id, version: 1, .notNow, in: &state, now: at)
    }
    #expect(defaults.isEmpty)
    #expect(state.flows[Flows.timing.id]?.outcome == .defaulted)
    #expect(!state.timing.on)
    #expect(due(state, date(2026, 11, 30, 15)) == nil)
  }

  // MARK: Tonight's reason

  @Test func tonightSaysWhyAWeeksStartMoved() throws {
    let state = TimingTests.held()
    let home = HomeSnapshot(state: state, log: [], now: date(2026, 11, 23, 15), calendar: london)
    #expect(home.hero.start == date(2026, 11, 23, 21, 30))
    let held = try #require(home.heldStart)
    #expect(held.offset == -30)
    #expect(held.text == "30 min earlier this week, to learn what helps")
    #expect(held.spoken == "30 minutes earlier this week, to learn what helps your sleep")
  }

  @Test func laterReadsLater() {
    let state = TimingTests.held(TimingTests.later)
    #expect(HeldStart(state)?.text == "30 min later this week, to learn what helps")
  }

  @Test func noReasonOnTheirOwnTimeOrOnceLocked() {
    let own = TimingTests.timed()
    let evening = HomeSnapshot(state: own, log: [], now: date(2026, 11, 23, 15), calendar: london)
    #expect(evening.heldStart == nil)
    var locked = TimingTests.held()
    run(&locked, date(2026, 11, 23, 22))
    let night = HomeSnapshot(state: locked, log: [], now: date(2026, 11, 23, 22), calendar: london)
    #expect(night.heldStart == nil)
  }

  /// The line takes the minutes-before-sleep line's place, so it must stay one line: the time
  /// above it doesn't move (D105). At the default size about 48 characters fit a 375 pt phone.
  @Test func theReasonIsShort() {
    for offset in TollConfig.defaults.timing.offsets where offset != 0 {
      #expect(Copy.Timing.held(offset).count <= 46)
    }
  }

  // MARK: Settings › Sleep

  @Test func theSwitchNeedsHealth() {
    var state = Self.withHealth
    state.health = false
    #expect(TimingSetting(state).kind == .needsHealth)
    #expect(TimingSetting(Self.withHealth).kind == .off)
    #expect(TimingSetting(Self.withHealth).detail == "Some weeks, up to 30 min earlier or later")
  }

  @Test func onItSaysThisWeeksStart() {
    #expect(TimingSetting(TimingTests.timed()).detail == "This week: your own time")
    #expect(TimingSetting(TimingTests.held()).kind == .on)
    #expect(TimingSetting(TimingTests.held()).detail == "This week: 30 min earlier")
  }
}

extension HomeSnapshot.Hero {
  fileprivate var start: Date? {
    if case .tonight(let start, _) = self { start } else { nil }
  }
}
