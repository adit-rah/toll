import Foundation
import Testing

@testable import TollCore

/// The buffers' targets from the person's own weeks (#145): the same as the Python reference on
/// every fixture, read from the night log, and offered by the one-time flow.
struct BufferSuggestionTests {
  struct Fixtures: Decodable {
    struct Case: Decodable {
      struct Expected: Decodable {
        var before: Int
        var after: Int
        var fitted: [String]
      }
      var name: String
      var before: [[Value]]
      var after: [[Value]]
      var late: [Int]
      var late_onset: Bool
      var expected: Expected
    }
    var rule: [String: Int]
    var cases: [Case]
  }

  enum Value: Decodable {
    case int(Int)
    case text(String)
    init(from decoder: Decoder) throws {
      let single = try decoder.singleValueContainer()
      if let int = try? single.decode(Int.self) {
        self = .int(int)
      } else {
        self = .text(try single.decode(String.self))
      }
    }
    var int: Int { if case .int(let value) = self { value } else { -1 } }
    var text: String { if case .text(let value) = self { value } else { "" } }
  }

  func fixtures() throws -> Fixtures {
    let url = try #require(
      Bundle.module.url(
        forResource: "suggestion", withExtension: "json", subdirectory: "Fixtures/buffers"))
    return try JSONDecoder().decode(Fixtures.self, from: Data(contentsOf: url))
  }

  func weeks(_ rows: [[Value]]) -> [BufferWeek] {
    rows.map { row in
      let verdict: Gap.Verdict =
        switch row[1].text {
        case "smooth": .smooth
        case "hard": .hard
        case "screenTimeOff": .screenTimeOff
        default: .hold
        }
      return BufferWeek(minutes: row[0].int, verdict: verdict, pauses: row[2].int)
    }
  }

  @Test func everyFixtureMatchesThePythonReference() throws {
    let fixtures = try fixtures()
    #expect(fixtures.cases.count > 300)
    for fixture in fixtures.cases {
      let late = BufferSuggestion.lateOnset(fixture.late, config: .defaults)
      #expect(late == fixture.late_onset, "\(fixture.name)")
      let suggestion = BufferSuggestion(
        before: weeks(fixture.before), after: weeks(fixture.after), lateOnset: late)
      #expect(suggestion.before == fixture.expected.before, "\(fixture.name)")
      #expect(suggestion.after == fixture.expected.after, "\(fixture.name)")
      #expect(
        Set(suggestion.fitted.map(\.rawValue)) == Set(fixture.expected.fitted), "\(fixture.name)")
    }
  }

  @Test func theReferenceUsesTollConfigsNumbers() throws {
    let rule = try fixtures().rule
    let config = TollConfig.defaults
    let suggestion = config.suggestion
    let expected: [String: Int] = [
      "before": suggestion.before, "after": suggestion.after,
      "before_low": suggestion.beforeLow, "before_high": suggestion.beforeHigh,
      "after_low": suggestion.afterLow, "after_high": suggestion.afterHigh,
      "min_weeks": suggestion.minWeeks, "lookback_weeks": suggestion.lookbackWeeks,
      "raise_smooth_weeks": suggestion.raiseSmoothWeeks,
      "late_onset_min": suggestion.lateOnsetMinutes, "health_nights": suggestion.healthNights,
      "before_step": config.gap.step, "after_step": config.after.step,
      "smooth_min_nights": config.gap.smoothMinNights,
      "smooth_max_pauses": config.gap.smoothMaxPauses, "hard_pauses": config.gap.hardPauses,
    ]
    #expect(rule == expected)
  }

  // MARK: From the night log

  /// One night from Monday 2 November 2026, each with the buffers and pauses given.
  func night(
    _ day: Int, before: Int = 60, after: Int = 30, pauses: (Int, Int)? = (0, 0), ran: Bool = true,
    off: Bool = false, late: Int? = nil
  ) -> BufferNight {
    BufferNight(
      night: london.startOfDay(for: date(2026, 11, day, 12)), ran: ran, before: before,
      after: after, pausesBefore: pauses?.0, pausesAfter: pauses?.1, screenTimeOff: off,
      late: late)
  }

  @Test func nightsMakeWeeksAsMondayJudgesThem() {
    // 2–8 Nov smooth at 45; 9–15 hard at 60; 16–22 at 60 but one record from before pauses were
    // kept; 23–29 is this week, not over.
    var nights = (2...8).map { night($0, before: 45) }
    nights += (9...15).map { night($0, pauses: $0 < 11 ? (1, 0) : (0, 0)) }
    nights += (16...22).map { night($0, pauses: $0 == 18 ? nil : (0, 0)) }
    nights += (23...26).map { night($0, pauses: (3, 0)) }
    let weeks = BufferSuggestion.weeks(.before, nights, calendar: london, config: .defaults)
    #expect(
      weeks == [
        BufferWeek(minutes: 45, verdict: .smooth, pauses: 0),
        BufferWeek(minutes: 60, verdict: .hard, pauses: 2),
        BufferWeek(minutes: 60, verdict: .hard, pauses: 12),
      ])
    let now = date(2026, 11, 27, 9)
    let suggestion = BufferSuggestion(nights: nights, now: now, calendar: london)
    // Two weeks judged on either side once this week's are left out: too few, the baseline.
    #expect(suggestion == BufferSuggestion())
  }

  @Test func aWeekTakesTheBufferMostNightsHad() {
    let nights = [30, 45, 45, 45, 30].enumerated().map {
      night(2 + $0.offset, before: $0.element)
    }
    #expect(
      BufferSuggestion.weeks(.before, nights, calendar: london, config: .defaults).first?.minutes
        == 45)
  }

  @Test func fourHardWeeksAt60LowerTheTarget() {
    // 26 Oct to 22 Nov: four weeks, hard at 60 twice; the after side calm at 30.
    var nights: [BufferNight] = []
    for (week, (minutes, pauses)) in [(45, 0), (60, 2), (45, 0), (60, 3)].enumerated() {
      for day in 0..<7 {
        let when = date(2026, 10, 26, 12).addingTimeInterval(Double(week * 7 + day) * 86_400)
        nights.append(
          BufferNight(
            night: london.startOfDay(for: when), ran: true, before: minutes, after: 30,
            pausesBefore: day == 0 ? pauses : 0, pausesAfter: 0, screenTimeOff: false))
      }
    }
    let suggestion = BufferSuggestion(nights: nights, now: date(2026, 11, 24, 9), calendar: london)
    #expect(suggestion.before == 45 && suggestion.after == 30)
    #expect(suggestion.fitted == [.before, .after])
  }

  @Test func healthsSignCountsOnlyNightsTheLockRan() {
    let ran = (2...15).map { night($0, late: 30) }
    #expect(BufferSuggestion.lateOnset(ran, config: .defaults))
    let some = (2...15).map { night($0, ran: $0 > 2, late: 30) }
    #expect(!BufferSuggestion.lateOnset(some, config: .defaults))
  }

  // MARK: Where pauses were asked

  @Test func pausesCountAgainstTheBufferTheyWereAskedIn() throws {
    let sleep = BlockID("sleep")
    func line(_ at: Date, _ cause: ReconcileCause, door: Door.Phase? = nil) -> Transition {
      Transition(
        at: at, cause: cause, blockOn: true, changed: false, home: true, inWindow: true,
        entitled: true, door: door, active: [sleep], screenTime: true)
    }
    let log = [
      line(date(2026, 11, 16, 22), .windowStart),
      // Asked in the buffer before sleep, opened a minute later.
      line(date(2026, 11, 16, 22, 10), .doorChosen, door: .waiting),
      line(date(2026, 11, 16, 22, 11), .doorStart, door: .open),
      line(date(2026, 11, 16, 22, 21), .doorEnd),
      // Asked and let go.
      line(date(2026, 11, 16, 23, 30), .doorChosen, door: .waiting),
      line(date(2026, 11, 16, 23, 30, 30), .doorCancelled),
      // Asked while asleep: against neither.
      line(date(2026, 11, 17, 2), .doorChosen, door: .waiting),
      line(date(2026, 11, 17, 2, 1), .doorStart, door: .open),
      line(date(2026, 11, 17, 2, 11), .doorEnd),
      // Asked in the buffer after waking.
      line(date(2026, 11, 17, 7, 5), .doorChosen, door: .waiting),
      line(date(2026, 11, 17, 7, 6), .doorStart, door: .open),
      line(date(2026, 11, 17, 7, 15), .windowEnd),
    ]
    var gap = Gap()
    gap.minutes = 30
    var after = Gap()
    after.minutes = 15
    let facts = try #require(
      NightFacts.ended(
        log: log, sleep: sleepBlock(), gap: gap, after: after, since: date(2026, 11, 16, 12),
        now: date(2026, 11, 17, 9), calendar: london
      ).first)
    #expect((facts.pausesBefore, facts.pausesAfter) == (1, 1))
    #expect((facts.waits, facts.waitsCancelled) == (4, 1))
    #expect(facts.unlocksUsed == 3)

    // The record keeps them, and the suggestion reads them back with Health's sleep.
    let data = try #require(NightRecordLine.encode(facts, calendar: london, model: stamp))
    var record = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    record["sleep_onset"] = "2026-11-16T22:55:00Z"
    let line = try JSONSerialization.data(withJSONObject: record)
    let read = try #require(NightRecordLine.buffers(line, calendar: london))
    #expect((read.pausesBefore, read.pausesAfter) == (1, 1))
    #expect((read.before, read.after, read.late) == (30, 15, 25))
    #expect(read.ran)
  }

  @Test func recordsFromBeforeReadAsUnknown() throws {
    let url = try #require(
      Bundle.module.url(
        forResource: "past", withExtension: "jsonl", subdirectory: "Fixtures/nights"))
    let nights = NightLog(url: url).buffers(calendar: london)
    #expect(nights.count == NightLog(url: url).current().count)
    #expect(nights.dropLast().allSatisfy { $0.pausesBefore == nil && $0.pausesAfter == nil })
    #expect(nights.last?.pausesBefore == 1)
  }

  // MARK: Offered

  @Test func theFlowOffersAFittedTargetOverALongerGap() {
    var state = setUp()
    state.gap = .growing(from: 60, to: 60)
    var suggestion = BufferSuggestion()
    suggestion.before = 45
    suggestion.fitted = [.before]
    let fit = Fit.existing(state, suggestion: suggestion)
    #expect(fit.before == .init(start: 45, target: 45))
    #expect(fit.after == .init(start: 15, target: 30))
    // The baseline keeps their gap, as before #145.
    #expect(Fit.existing(state).before == .init(start: 60, target: 60))
  }
}
