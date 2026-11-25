import Foundation
import SleepModel
import Testing

@testable import TollCore

/// D80: Before bed's helpers. The capsule and its one card only in the gap between the lock and
/// bed; Settings' switch and the breath's length; the breath's shape; the private `helper` in the
/// night record; and nothing counted anywhere.
struct BeforeBedTests {
  /// Set up on Monday the 16th, home set and at home, bought, the heads-up answered: a new install,
  /// so apps lock at 10:15 pm, 15 minutes before bed at 10:30.
  func installed(home: Bool = true) -> DuskState {
    var state = setUp()
    if !home { state.blocks = [sleepBlock(place: nil)] }
    #expect(
      apply(
        .finishSetup(
          sleep: sleepBlock(place: home ? homePlace.id : nil), home: home ? homePlace : nil,
          trialStart: date(2026, 11, 16, 15)), &state, date(2026, 11, 16, 15)) == nil)
    state.trial.purchased = true
    state.dismissedCards = [TonightCard.headsUp.rawValue]
    run(&state, date(2026, 11, 16, 15))
    return state
  }

  /// Tuesday's lock has started: 10:20 pm, ten minutes before bed.
  func inTheGap(_ state: DuskState = BeforeBedTests().installed()) -> DuskState {
    var state = state
    run(&state, date(2026, 11, 17, 22, 15), .windowStart)
    return state
  }

  func home(_ state: DuskState, _ now: Date) -> HomeSnapshot {
    HomeSnapshot(state: state, log: [], now: now, calendar: london)
  }

  // MARK: Tonight

  @Test func theCapsuleShowsOnlyBetweenTheLockAndBed() {
    let state = inTheGap()
    #expect(home(state, date(2026, 11, 17, 22, 20)).untilBed == 10)
    #expect(home(state, date(2026, 11, 17, 22, 29, 30)).untilBed == 1)
    // Before the lock, and once bed has come.
    #expect(home(installed(), date(2026, 11, 17, 21)).untilBed == nil)
    var later = state
    run(&later, date(2026, 11, 17, 22, 31))
    #expect(home(later, date(2026, 11, 17, 22, 31)).untilBed == nil)
  }

  @Test func noCapsuleWithNoGapDuringAPauseOrSwitchedOff() {
    var none = installed()
    #expect(apply(.gap(.fixed(0)), &none, date(2026, 11, 17, 12)) == nil)
    run(&none, date(2026, 11, 17, 22, 30), .windowStart)
    #expect(home(none, date(2026, 11, 17, 22, 40)).untilBed == nil)

    var paused = inTheGap()
    #expect(apply(.startDoor, &paused, date(2026, 11, 17, 22, 16)) == nil)
    run(&paused, date(2026, 11, 17, 22, 18), .doorStart)
    #expect(home(paused, date(2026, 11, 17, 22, 18)).untilBed == nil)

    var off = inTheGap()
    #expect(apply(.helpers(Helpers(on: false)), &off, date(2026, 11, 17, 22, 20)) == nil)
    #expect(home(off, date(2026, 11, 17, 22, 20)).untilBed == nil)
    #expect(home(off, date(2026, 11, 17, 22, 20)).card == nil)
  }

  @Test func oneCardIntroducesItOnceWithTheMinutesLeft() {
    var state = inTheGap()
    let now = date(2026, 11, 17, 22, 20)
    #expect(home(state, now).card == .beforeBed)
    #expect(
      Copy.Helpers.card(minutes: home(state, now).untilBed ?? 0)
        == "Something for the next 10 minutes?")
    #expect(Copy.Helpers.card(minutes: 1) == "Something for the next minute?")
    #expect(apply(.dismissCard(.beforeBed), &state, now) == nil)
    #expect(home(state, now).card == nil)
    #expect(home(state, now).untilBed == 10)
  }

  /// Warnings first, then home, then the heads-up, then this: the offers are quiet while the lock
  /// is on, so in the gap this is the only card, and a warning still holds the slot.
  @Test func theCardComesAfterWarningsAndOffers() {
    let anywhere = installed(home: false)
    #expect(home(anywhere, date(2026, 11, 17, 21)).card == .home)
    #expect(home(inTheGap(anywhere), date(2026, 11, 17, 22, 20)).card == .beforeBed)

    var noLocation = inTheGap()
    noLocation.location = .scheduleOnly
    let warned = home(noLocation, date(2026, 11, 17, 22, 20))
    #expect(warned.locationBanner && warned.card == nil)
  }

  // MARK: Settings

  @Test func onByDefaultAndTheBreathStaysInItsRange() {
    var state = installed()
    #expect(state.helpers.on)
    #expect(state.helpers.breath(.defaults) == 3)
    #expect(
      apply(.helpers(Helpers(on: true, breathMinutes: 25)), &state, date(2026, 11, 17, 12)) == nil)
    #expect(state.helpers.breathMinutes == 10)
    #expect(
      apply(.helpers(Helpers(on: false, breathMinutes: 0)), &state, date(2026, 11, 17, 12)) == nil)
    #expect(state.helpers == Helpers(on: false, breathMinutes: 1))
  }

  @Test func aFileFromBeforeHasThemOn() throws {
    var state = installed()
    state.helpers = Helpers(on: false, breathMinutes: 5)
    let data = try DuskStore.encoder.encode(state)
    #expect(try DuskStore.decoder.decode(DuskState.self, from: data).helpers == state.helpers)
    var json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    json["helpers"] = nil
    let old = try JSONSerialization.data(withJSONObject: json)
    #expect(try DuskStore.decoder.decode(DuskState.self, from: old).helpers == Helpers())
  }

  // MARK: The breath

  @Test func aboutSixBreathsAMinuteRisingInFallingOut() {
    let breath = Breath(minutes: 3)
    #expect(breath.perMinute == 6)
    #expect(breath.length == 180)
    #expect(breath.pitch(at: 0) == 0)
    #expect(abs(breath.pitch(at: 4.5) - 1) < 1e-9)
    #expect(breath.pitch(at: 2) < breath.pitch(at: 4))
    #expect(breath.pitch(at: 6) > breath.pitch(at: 9))
    #expect(abs(breath.pitch(at: 10)) < 1e-9)
  }

  @Test func theToneComesInSwellsAndFadesAway() {
    let breath = Breath(minutes: 3)
    #expect(breath.gain(at: -1) == 0 && breath.gain(at: 0) == 0)
    #expect(abs(breath.gain(at: 94.5) - 1) < 1e-9)
    #expect(breath.gain(at: 100) < breath.gain(at: 94.5))
    #expect(breath.gain(at: 170) < breath.gain(at: 160))
    #expect(breath.gain(at: 180) == 0)
    #expect(Breath(minutes: 10).length == 600)
  }

  // MARK: The night record

  func line(_ at: Date, _ cause: ReconcileCause, on: Bool = true) -> Transition {
    Transition(
      at: at, cause: cause, blockOn: on, changed: false, home: true, inWindow: on, entitled: true,
      active: on ? [BlockID("sleep")] : [], screenTime: true)
  }

  @Test func theRecordSaysWhichHelperPrivately() throws {
    let log = [
      line(date(2026, 11, 17, 22, 15), .windowStart),
      line(date(2026, 11, 17, 22, 17), .helperList),
      line(date(2026, 11, 17, 22, 19), .helperBreathe),
      line(date(2026, 11, 18, 7), .windowEnd, on: false),
      line(date(2026, 11, 18, 22, 15), .windowStart),
      line(date(2026, 11, 19, 7), .windowEnd, on: false),
    ]
    let state = installed()
    let nights = NightFacts.ended(
      log: log, sleep: sleepBlock(), gap: state.gap, since: date(2026, 11, 17, 12),
      now: date(2026, 11, 19, 9), calendar: london)
    #expect(nights.map(\.helper) == [.breathe, nil])
    // Nothing else about the night moves: the block screen wasn't touched.
    #expect(nights.first?.stops == 0 && nights.first?.doorAsks == 0)
    let used = try JSONDecoder().decode(
      NightRecord.self, from: try #require(NightRecordLine.encode(nights[0], calendar: london)))
    #expect(used.helper == "breathe")
    let none = try #require(NightRecordLine.encode(nights[1], calendar: london))
    #expect(try JSONDecoder().decode(NightRecord.self, from: none).helper == nil)
    let raw = try #require(try JSONSerialization.jsonObject(with: none) as? [String: Any])
    #expect(raw["helper"] is NSNull)
  }

  /// Never counted: the week, the morning hero and Your sleep read the same with or without it.
  @Test func nothingCountsAHelper() {
    let state = installed()
    let plain = [
      line(date(2026, 11, 17, 22, 15), .windowStart),
      line(date(2026, 11, 18, 7), .windowEnd, on: false),
    ]
    let helped = plain + [line(date(2026, 11, 17, 22, 18), .helperWords)]
    let morning = date(2026, 11, 18, 8)
    let a = HomeSnapshot(state: state, log: plain, now: morning, calendar: london)
    let b = HomeSnapshot(state: state, log: helped, now: morning, calendar: london)
    #expect(a.morning == b.morning && a.bars == b.bars)
    let sleepA = YourSleep(state: state, log: plain, history: [], now: morning, calendar: london)
    let sleepB = YourSleep(state: state, log: helped, history: [], now: morning, calendar: london)
    #expect(sleepA == sleepB)
  }
}
