import Foundation
import SleepModel
import Testing

@testable import TollCore

/// Personal timing in the night records (D99, #155): every night of a hold logs `policy` "held",
/// `hold_start`, `settled` and the hold's offset and chance, exactly as `SleepModel.NightRecord`
/// reads them; the latest line gives the hold back after a rebuild; and the app's draw, through
/// the model, keeps one start a week and replays the same from the same generator.
struct TimingRecordTests {
  /// Monday to Wednesday's nights of the held week, the lock running 9:30 pm to 7 am, Tuesday away.
  static func log() -> [Transition] {
    func line(_ at: Date, _ cause: ReconcileCause, on: Bool, home: Bool = true) -> Transition {
      Transition(
        at: at, cause: cause, blockOn: on, changed: true, home: home, inWindow: on || !home,
        entitled: true,
        active: on ? [BlockID("sleep")] : [])
    }
    return [
      line(date(2026, 11, 23, 21, 30), .windowStart, on: true),
      line(date(2026, 11, 24, 7), .windowEnd, on: false),
      line(date(2026, 11, 24, 21, 30), .windowStart, on: false, home: false),
      line(date(2026, 11, 25, 7), .windowEnd, on: false, home: false),
      line(date(2026, 11, 25, 21, 30), .windowStart, on: true),
      line(date(2026, 11, 26, 7), .windowEnd, on: false),
    ]
  }

  static func records(_ state: DuskState, now: Date = date(2026, 11, 26, 9)) throws
    -> [NightRecord]
  {
    let sleep = try #require(state.sleepBlock)
    return try NightFacts.ended(
      log: log(), sleep: sleep, gap: state.gap, after: state.after, timing: state.timing,
      since: date(2026, 11, 23, 9), now: now, calendar: london
    ).map { facts in
      let line = try #require(NightRecordLine.encode(facts, calendar: london, model: stamp))
      return try JSONDecoder().decode(NightRecord.self, from: line)
    }
  }

  @Test func everyNightOfTheHoldLogsItAsTheModelReadsIt() throws {
    let records = try Self.records(TimingTests.held())
    #expect(records.map(\.night) == ["2026-11-23", "2026-11-24", "2026-11-25"])
    for record in records {
      #expect(record.policy == "held")
      #expect(record.holdStart == "2026-11-23")
      #expect(record.settled == false)
      #expect(record.actionOffsetMin == -30)
      #expect(record.actionProb == 0.4)
      #expect(record.gapMin == 30)
      #expect(record.hold == Hold(start: "2026-11-23", offset: -30, prob: 0.4, settled: false))
    }
    // The away night too, though the lock didn't run (D99).
    #expect(records[1].blockStart == nil)
    #expect(records[1].awayAllNight)
    // Bed stays where it was: sleep is measured from it.
    #expect(records[0].bed == "2026-11-23T22:30:00Z")
    #expect(Hold.latest(in: records) == records[2].hold)
  }

  @Test func nightsBeforeTheHoldRunAtThePlanAndSayFixed() throws {
    var state = TimingTests.timed()
    let wednesday = date(2026, 11, 25, 15)
    run(&state, wednesday)
    var hold = TimingTests.earlier
    hold.start = "2026-11-25"
    _ = apply(.hold(hold, generator: 1), &state, wednesday)
    let records = try Self.records(state)
    #expect(records.map(\.policy) == ["fixed", "fixed", "held"])
    #expect(records.map(\.actionOffsetMin) == [0, 0, -30])
    #expect(records[0].actionProb == 1)
    #expect(records[0].holdStart == nil)
    #expect(records[0].settled == nil)
  }

  @Test func withoutTimingTheRecordIsAsItWas() throws {
    let records = try Self.records(TimingTests.timed())
    #expect(
      records.allSatisfy { $0.policy == "fixed" && $0.hold == nil && $0.actionOffsetMin == 0 })
  }

  /// The app's part, as `ModelStore.choose` does it: ask, draw with the model, answer.
  static func draw(_ state: inout DuskState, now: Date, nights: [NightRecord] = [])
    -> SeededRNG?
  {
    guard let ask = TimingRules.ask(state, now: now, calendar: london) else { return nil }
    let model = SleepModel(artifact: ModelArtifact.bundled(), nights: nights)
    var rng = SeededRNG(seed: ask.generator ?? 2026)
    let held = ask.held.map {
      Hold(start: $0.start, offset: $0.offset, prob: $0.prob, settled: $0.settled)
    }
    let hold = model.chooseStart(
      night: ask.night, NightContext(weekend: ask.weekend, allowedOffsets: ask.allowed),
      held: Hold.latest(in: nights) ?? held, rng: &rng)
    let answer = Timing.Hold(
      start: hold.start, offset: hold.offset, prob: hold.prob, settled: hold.settled)
    _ = apply(.hold(answer, generator: rng.state), &state, now)
    run(&state, now)
    return rng
  }

  @Test func theOffsetsAreTheArtifactsActions() {
    #expect(TollConfig.defaults.timing.offsets == ModelArtifact.bundled().actions)
  }

  @Test func aDrawHoldsTheWeekAndTheSameGeneratorDrawsTheSame() throws {
    var a = TimingTests.timed()
    var b = TimingTests.timed()
    let monday = date(2026, 11, 23, 15)
    run(&a, monday)
    run(&b, monday)
    let rng = try #require(Self.draw(&a, now: monday))
    _ = Self.draw(&b, now: monday)
    #expect(a.timing == b.timing)
    #expect(a.timing.generator == String(rng.state))
    let hold = try #require(a.timing.inForce)
    #expect(hold.start == "2026-11-23")
    #expect(hold.prob >= 0.1)
    // Later in the week there's nothing to draw; next Monday there is, from where it left off.
    #expect(Self.draw(&a, now: date(2026, 11, 27, 9)) == nil)
    run(&a, date(2026, 11, 30, 13))
    #expect(
      TimingRules.ask(a, now: date(2026, 11, 30, 13), calendar: london)?.generator == rng.state)
  }

  /// D92, D99: the state lost its timing (an older build wrote it, or it couldn't be read), and
  /// the model, rebuilt from the night log, keeps the week's start the latest line names: no draw,
  /// the generator untouched.
  @Test func aRebuildGivesTheHoldBackFromTheLatestRecord() throws {
    let records = try Self.records(TimingTests.held())
    var state = TimingTests.timed()
    let thursday = date(2026, 11, 26, 15)
    run(&state, thursday)
    let rng = try #require(Self.draw(&state, now: thursday, nights: records))
    #expect(rng.state == 2026)
    #expect(state.timing.inForce == TimingTests.earlier)
    #expect(TimingTests.lockStart(state) == time(21, 30))
  }

  @Test func recoveryBringsTheWeeksStartBack() throws {
    let records = try Self.records(TimingTests.held())
    let line = try JSONEncoder().encode(try #require(records.last))
    let record = try #require(try JSONSerialization.jsonObject(with: line) as? [String: Any])
    var state = DuskState()
    Recovery.restoreNight(&state, from: record, now: date(2026, 11, 26, 9))
    #expect(state.timing.on)
    #expect(state.health)
    #expect(state.timing.inForce == TimingTests.earlier)
    var plain = record
    plain["policy"] = "fixed"
    var other = DuskState()
    Recovery.restoreNight(&other, from: plain, now: date(2026, 11, 26, 9))
    #expect(other.timing == Timing())
  }
}
