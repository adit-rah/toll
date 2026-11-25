import Foundation
import Testing

@testable import TollCore

/// One-time flows (#140): asked once per version, only at a calm moment, at most one a day, and
/// put off for good with their defaults after the last "Not now".
struct FlowTests {
  let sample = OneTimeFlow(
    id: "example", version: 1, applies: { $0.setupFinishedAt != nil },
    defaults: { _ in [.headsUp(false)] })

  /// Set up on Monday morning, the night 10:30 pm to 7 am.
  var state: DuskState {
    var state = setUp()
    state.setupFinishedAt = date(2026, 11, 16, 9)
    return state
  }

  func due(_ state: DuskState, _ now: Date) -> String? {
    Flows.due(state, now: now, calendar: london, registry: [sample])?.id
  }

  @Test func theRegistryHoldsFitSleepAlone() {
    #expect(Flows.registry.map(\.id) == ["fit-sleep"])
    // Set up after #144: nothing to ask.
    #expect(Flows.due(state, now: date(2026, 11, 17, 15), calendar: london) == nil)
  }

  @Test func aCalmAfternoonIsAMoment() {
    #expect(due(state, date(2026, 11, 17, 15)) == "example")
    #expect(due(state, date(2026, 11, 17, 8)) == "example")
  }

  @Test func neverBeforeSetup() {
    var fresh = state
    fresh.setupFinishedAt = nil
    #expect(due(fresh, date(2026, 11, 17, 15)) == nil)
  }

  @Test func neverDuringTheNightOrItsGap() {
    #expect(due(state, date(2026, 11, 17, 23)) == nil)
    #expect(due(state, date(2026, 11, 18, 6, 59)) == nil)
    var gap = state
    gap.gap.minutes = 30
    #expect(due(gap, date(2026, 11, 17, 22, 10)) == nil)
  }

  @Test func neverInTheMinutesBeforeTheLock() {
    #expect(due(state, date(2026, 11, 17, 22, 15)) == nil)
    #expect(due(state, date(2026, 11, 17, 22, 5)) == "example")
    var gap = state
    gap.gap.minutes = 30
    #expect(due(gap, date(2026, 11, 17, 21, 45)) == nil)
  }

  @Test func neverWhileABlockIsOnOrAPauseIsAsked() {
    var study = state
    study.runtime.active[BlockID("study")] = date(2026, 11, 17, 17)
    #expect(due(study, date(2026, 11, 17, 15)) == nil)
    var asked = state
    asked.doorAskedAt = date(2026, 11, 17, 14, 59)
    #expect(due(asked, date(2026, 11, 17, 15)) == nil)
  }

  @Test func oncePerVersion() {
    var answered = state
    _ = Flows.record("example", version: 1, .answered, in: &answered, now: date(2026, 11, 16, 15))
    #expect(due(answered, date(2026, 11, 17, 15)) == nil)
    var bumped = sample
    bumped.version = 2
    #expect(
      Flows.due(answered, now: date(2026, 11, 17, 15), calendar: london, registry: [bumped])?.id
        == "example")
  }

  /// One flow a day: the one offered today stays offered all day, until answered or put off, and
  /// comes back on a later day; no other flow joins it that day.
  @Test func theFlowOfferedTodayStaysAllDay() {
    let other = OneTimeFlow(
      id: "other", version: 1, applies: { $0.setupFinishedAt != nil }, defaults: { _ in [] })
    var shown = state
    _ = Flows.record("example", version: 1, .shown, in: &shown, now: date(2026, 11, 17, 9))
    #expect(due(shown, date(2026, 11, 17, 15)) == "example")
    // Still never at a moment that isn't calm.
    #expect(due(shown, date(2026, 11, 17, 23)) == nil)
    #expect(due(shown, date(2026, 11, 18, 15)) == "example")
    // A second flow waits for another day.
    var answered = shown
    _ = Flows.record("example", version: 1, .answered, in: &answered, now: date(2026, 11, 17, 16))
    let both = [sample, other]
    #expect(Flows.due(answered, now: date(2026, 11, 17, 17), calendar: london, registry: both) == nil)
    #expect(
      Flows.due(answered, now: date(2026, 11, 18, 15), calendar: london, registry: both)?.id
        == "other")
    // "Not now" puts it away for the rest of the day.
    var notNow = shown
    _ = Flows.record("example", version: 1, .notNow, in: &notNow, now: date(2026, 11, 17, 10))
    #expect(due(notNow, date(2026, 11, 17, 15)) == nil)
    #expect(due(notNow, date(2026, 11, 18, 15)) == "example")
  }

  @Test func theLastNotNowAppliesItsDefaults() {
    var s = state
    let config = TollConfig.defaults
    for day in 0..<(config.flows.offers - 1) {
      let at = date(2026, 11, 17 + day, 15)
      #expect(due(s, at) == "example")
      #expect(
        Flows.record("example", version: 1, .notNow, in: &s, now: at, registry: [sample]).isEmpty)
    }
    let last = date(2026, 11, 17 + config.flows.offers, 15)
    let defaults = Flows.record(
      "example", version: 1, .notNow, in: &s, now: last, registry: [sample])
    #expect(s.flows["example"]?.outcome == .defaulted)
    #expect(defaults.count == 1)
    #expect(due(s, date(2026, 11, 30, 15)) == nil)
  }

  @Test func theCommandRecordsItInTheState() {
    var s = state
    #expect(apply(.flow(id: "example", version: 1, .answered), &s, date(2026, 11, 17, 15)) == nil)
    #expect(
      s.flows["example"] == FlowRecord(version: 1, outcome: .answered, at: date(2026, 11, 17, 15)))
  }

  @Test func anOutcomeFromANewerBuildCountsAsAnswered() throws {
    let data = Data(#"{"version":1,"outcome":"skippedForever","at":"2026-11-17T15:00:00Z"}"#.utf8)
    let record = try DuskStore.decoder.decode(FlowRecord.self, from: data)
    #expect(record.done)
  }
}
