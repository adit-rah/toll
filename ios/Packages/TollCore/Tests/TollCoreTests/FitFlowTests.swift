import Foundation
import SleepModel
import Testing

@testable import TollCore

/// #144 for people already using Dusk: schema 4 keeps their night as it was, one-time flow #1
/// "Fit Dusk to your sleep" offers sleep and both buffers once, and night records carry the buffer
/// after and, a day later, Health's sleep as a correction.
struct FitFlowTests {
  /// The v3 fixture, read by this build: set up, the night on, a pause asked.
  func migrated() throws -> DuskState {
    var state = DuskStore.reading(try StateFixtureTests.fixture("v3")).state
    // A calm afternoon: no night, no pause.
    state.runtime.active = [:]
    state.door = nil
    state.doorAskedAt = nil
    state.pending = [:]
    return state
  }

  @Test func aPersonFromBeforeKeepsTheirNightAndIsOfferedTheFit() throws {
    let state = try migrated()
    #expect(state.after.offered)
    #expect(state.lockSleep?.schedule.windows == [TimeWindow(start: time(22, 15), end: time(7))])
    #expect(Flows.fitSleep.applies(state))
    #expect(Flows.due(state, now: date(2026, 11, 26, 15), calendar: london)?.id == "fit-sleep")
    // Never in the night, nor in the minutes before the lock.
    #expect(Flows.due(state, now: date(2026, 11, 26, 22, 0), calendar: london) == nil)
  }

  @Test func aNewInstallIsNeverAsked() {
    var state = setUp()
    _ = apply(
      .finishSetup(
        sleep: sleepBlock(), home: homePlace, trialStart: date(2026, 11, 16, 15),
        fit: .suggested(sleep: nil, BufferSuggestion(nil), health: false)),
      &state, date(2026, 11, 16, 15))
    #expect(!Flows.fitSleep.applies(state))
  }

  @Test func theFlowStartsFromTheirNightAndGap() throws {
    let state = try migrated()
    let fit = Fit.existing(state, BufferSuggestion(nil))
    #expect(fit.sleep == .everyDay(usual))
    // Their held change to 30 counts; the target is D76's 60.
    #expect(fit.before == .init(start: 30, target: 60))
    #expect(fit.after == .init(start: 10, target: 30))
  }

  @Test func answeringFitsTheNightAndEndsTheFlow() throws {
    var state = try migrated()
    let now = date(2026, 11, 26, 15)
    let fit = Fit(
      sleep: .everyDay(TimeWindow(start: time(23, 20), end: time(7, 10))),
      before: .init(start: 15, target: 75), after: .init(start: 10, target: 30), health: true)
    #expect(apply(.fit(fit), &state, now) == nil)
    #expect(apply(.flow(id: "fit-sleep", version: 1, .answered), &state, now) == nil)
    #expect(state.lockSleep?.schedule.windows == [TimeWindow(start: time(23, 5), end: time(7, 20))])
    #expect(!state.after.offered)
    #expect(Flows.due(state, now: date(2026, 11, 28, 15), calendar: london) == nil)
  }

  @Test func putOffForGoodItLeavesTheNightAsItWas() throws {
    var state = try migrated()
    let lock = state.lockSleep?.schedule
    for day in 0..<TollConfig.defaults.flows.offers {
      let at = date(2026, 11, 26 + day, 15)
      #expect(Flows.due(state, now: at, calendar: london)?.id == "fit-sleep")
      #expect(apply(.flow(id: "fit-sleep", version: 1, .notNow), &state, at) == nil)
    }
    #expect(state.flows["fit-sleep"]?.outcome == .defaulted)
    #expect(state.lockSleep?.schedule == lock)
    #expect(state.after.minutes == 0)
    #expect(!state.after.offered)
    #expect(Flows.due(state, now: date(2026, 12, 2, 15), calendar: london) == nil)
  }

  // MARK: Night records

  func files() -> NightLog {
    let folder = FileManager.default.temporaryDirectory.appending(
      path: "fit-\(UUID().uuidString)", directoryHint: .isDirectory)
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    return NightLog(url: folder.appending(path: "nights.jsonl"))
  }

  /// Monday night: the lock 10:15 pm to 7:10 am around sleep 10:30 to 7.
  func monday() throws -> NightFacts {
    let on = Transition(
      at: date(2026, 11, 16, 22, 15), cause: .windowStart, blockOn: true, changed: true,
      home: true, inWindow: true, entitled: true, active: [BlockID("sleep")])
    var off = on
    off.at = date(2026, 11, 17, 7, 10)
    off.blockOn = false
    off.active = []
    var gap = Gap.growing(from: 15, to: 60)
    gap.history = [.init(night: .distantPast, minutes: 15)]
    var after = Gap.growing(from: 10, to: 30)
    after.history = [.init(night: .distantPast, minutes: 10)]
    return try #require(
      NightFacts.ended(
        log: [on, off], sleep: sleepBlock(), gap: gap, after: after,
        since: date(2026, 11, 16, 9), now: date(2026, 11, 17, 9), calendar: london
      ).first)
  }

  @Test func aRecordCarriesPlannedSleepAndBothBuffers() throws {
    let facts = try monday()
    #expect(facts.plannedEnd == date(2026, 11, 17, 7, 10))
    #expect(facts.locked == 535 * 60)
    let data = try #require(NightRecordLine.encode(facts, calendar: london, model: stamp))
    let record = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(record["record"] as? Int == 3)
    #expect(record["after_min"] as? Int == 10)
    #expect(record["gap_min"] as? Int == 15)
    #expect(record["planned_wake"] as? String == "2026-11-17T07:00:00Z")
    #expect(record["block_end"] as? String == "2026-11-17T07:10:00Z")
    #expect(try JSONDecoder().decode(NightRecord.self, from: data).plannedWake.hasPrefix("2026"))
  }

  @Test func healthsSleepArrivesAsACorrection() throws {
    let log = files()
    #expect(log.record([try monday()], calendar: london, model: stamp) == 1)
    #expect(log.missingSleep(since: date(2026, 11, 10, 12), calendar: london) == ["2026-11-16"])
    let slept = SleepNight(
      night: date(2026, 11, 16, 0), onset: date(2026, 11, 16, 23, 5),
      wake: date(2026, 11, 17, 6, 50), asleepMinutes: 440, awakeMinutes: 15, inBed: nil,
      source: .watch)
    #expect(log.correct(with: [slept], calendar: london) == 1)
    // Once corrected, nothing more to add.
    #expect(log.correct(with: [slept], calendar: london) == 0)
    #expect(log.lines().count == 2)
    let current = try #require(log.current().first)
    let record = try JSONDecoder().decode(NightRecord.self, from: current)
    #expect(record.rev == 2)
    #expect(record.sleepOnset == "2026-11-16T23:05:00Z")
    #expect(record.asleepMin == 440)
    #expect(record.sleepSource == "watch")
    #expect(record.features(ModelArtifact.bundled()).skip == nil)
    #expect(log.missingSleep(since: date(2026, 11, 10, 12), calendar: london).isEmpty)
  }

  @Test func aLostNightComesBackWithItsBufferAfter() {
    var state = DuskState()
    let record: [String: Any] = [
      "bed": "2026-11-16T22:30:00Z", "planned_wake": "2026-11-17T07:00:00Z", "gap_min": 15,
      "after_min": 10,
    ]
    Recovery.restoreNight(&state, from: record, now: date(2026, 11, 17, 9))
    #expect(state.gap.minutes == 15)
    #expect(state.after.minutes == 10)
    #expect(
      state.lockSleep?.schedule.windows == [TimeWindow(start: time(22, 15), end: time(7, 10))])
  }
}
