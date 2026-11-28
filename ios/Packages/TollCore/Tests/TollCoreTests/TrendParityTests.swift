import Foundation
import Testing

@testable import TollCore

/// Your sleep's trend rule against its Python reference (#165, `datascience/trends/`): the same
/// values, the same weekly judgements and the same ways on every fixture.
struct TrendParityTests {
  struct Fixtures: Decodable {
    struct Change: Decodable {
      var way: String
      var d: Double
      var look: Int?
      var first: Int
    }
    struct Expected: Decodable {
      var value: Double
      var nights: Int
      var first: Double?
      var middle: Double?
      var first_middle: Double?
      var change: Change?
    }
    struct Case: Decodable {
      var name: String
      var kind: String
      var floor: Double
      var lower: Bool
      var nights: [[Double]]
      var now: Int
      var expected: Expected?
    }
    var rule: [String: Value]
    var cases: [Case]
  }

  enum Value: Decodable {
    case number(Double)
    case text(String)
    init(from decoder: Decoder) throws {
      let single = try decoder.singleValueContainer()
      if let number = try? single.decode(Double.self) {
        self = .number(number)
      } else {
        self = .text(try single.decode(String.self))
      }
    }
    var number: Double { if case .number(let value) = self { value } else { .nan } }
  }

  func fixtures() throws -> Fixtures {
    let url = try #require(
      Bundle.module.url(
        forResource: "trends", withExtension: "json", subdirectory: "Fixtures/trends"))
    return try JSONDecoder().decode(Fixtures.self, from: Data(contentsOf: url))
  }

  /// Day 0 is Monday 2 November 2026's night.
  func night(_ day: Int) -> Date {
    london.date(byAdding: .day, value: day, to: date(2026, 11, 2, 0)) ?? .distantPast
  }

  func reader(now: Int) -> Reader {
    Reader(
      past: [], anchor: night(now), calendar: london, rules: TollConfig.defaults.trends,
      weekday: TollConfig.defaults.unlocks.refillWeekday)
  }

  func way(_ way: SleepTrends.Way) -> String {
    switch way {
    case .toward: "toward"
    case .away: "away"
    case .steady: "steady"
    }
  }

  func close(_ a: Double?, _ b: Double?) -> Bool {
    switch (a, b) {
    case (nil, nil): true
    case (let a?, let b?): abs(a - b) < 1e-6
    default: false
    }
  }

  @Test func everyFixtureMatchesThePythonReference() throws {
    let fixtures = try fixtures()
    #expect(fixtures.cases.count > 400)
    let rules = TollConfig.defaults.trends
    for fixture in fixtures.cases {
      let reader = reader(now: fixture.now)
      let series: NightSeries = fixture.nights.map { (night(Int($0[0])), $0[1]) }
      let recent = series.filter {
        reader.isRecent($0.night, nights: fixture.kind == "steady" ? rules.steadyNights : nil)
      }
      let least = fixture.kind == "steady" ? rules.minSteady : rules.minShow
      guard let expected = fixture.expected else {
        #expect(recent.count < least, "\(fixture.name)")
        continue
      }
      #expect(recent.count == expected.nights, "\(fixture.name)")
      switch fixture.kind {
      case "locked":
        let past = fixture.nights.map { PastNight(night: night(Int($0[0])), ran: $0[1] > 0) }
        let measure = Reader(
          past: past, anchor: night(fixture.now), calendar: london, rules: rules,
          weekday: TollConfig.defaults.unlocks.refillWeekday
        ).nightsLocked()
        #expect(measure?.change.map { way($0.way) } == expected.change?.way, "\(fixture.name)")
        #expect(close(measure?.change?.by, expected.change?.d), "\(fixture.name)")
      case "steady":
        let value = Stats.trimmed(Stats.deviations(recent.map(\.value)), rules.trim)
        #expect(close(value, expected.value), "\(fixture.name)")
        #expect(close(Stats.median(recent.map(\.value)), expected.middle), "\(fixture.name)")
        let (found, then) = reader.looks(
          series, floor: rules.floorSteady, lowerIsBetter: true, steady: true)
        compare(reader.inForce(found), then, expected, fixture.name)
      default:
        #expect(
          close(Stats.trimmed(recent.map(\.value), rules.trim), expected.value), "\(fixture.name)")
        let (found, then) = reader.looks(
          series, floor: fixture.floor, lowerIsBetter: fixture.lower)
        compare(reader.inForce(found), then, expected, fixture.name)
      }
    }
  }

  func compare(
    _ look: TrendLook?, _ then: [Double], _ expected: Fixtures.Expected, _ name: String
  ) {
    #expect(look.map { way($0.way) } == expected.change?.way, "\(name)")
    #expect(close(look?.d, expected.change?.d), "\(name)")
    #expect(look?.look == expected.change?.look, "\(name)")
    #expect(
      close(look.map { _ in Stats.trimmed(then, TollConfig.defaults.trends.trim) }, expected.first),
      "\(name)")
  }

  @Test func theReferenceUsesTollConfigsNumbers() throws {
    let rule = try fixtures().rule
    let t = TollConfig.defaults.trends
    #expect(rule["baseline"]?.number == Double(t.baselineNights))
    #expect(rule["recent"]?.number == Double(t.recentNights))
    #expect(rule["min_show"]?.number == Double(t.minShow))
    #expect(rule["min_recent"]?.number == Double(t.minRecent))
    #expect(rule["floor_minutes"]?.number == t.floorMinutes)
    #expect(rule["floor_reaches"]?.number == t.floorReaches)
    #expect(rule["floor_nights"]?.number == t.floorNights)
    #expect(rule["steady"]?.number == Double(t.steadyNights))
    #expect(rule["min_steady"]?.number == Double(t.minSteady))
    #expect(rule["min_steady_recent"]?.number == Double(t.minSteadyRecent))
    #expect(rule["floor_steady"]?.number == t.floorSteady)
    #expect(rule["trim"]?.number == t.trim)
    #expect(rule["miss"]?.number == t.miss)
    #expect(rule["power"]?.number == t.spendPower)
  }
}
