import Foundation
import Testing

@testable import TollCore

struct DayMathTests {
  struct Input: Decodable, Sendable {
    let instant: String
    let timeZone: String
    let resetHour: Int
  }
  struct Expected: Decodable, Sendable {
    let day: String
    let week: String
    let hour: Int
  }

  static let cases =
    (try? Fixtures.load("day-math.json", as: FixtureFile<Input, Expected>.self).cases) ?? []

  @Test("fixtures load") func fixturesLoad() { #expect(Self.cases.count >= 10) }

  @Test(arguments: cases)
  func dayWeekAndHour(_ c: FixtureFile<Input, Expected>.Case) throws {
    let zone = try #require(TimeZone(identifier: c.input.timeZone))
    let math = DayMath(timeZone: zone, resetHour: c.input.resetHour)
    let date = Fixtures.instant(c.input.instant)
    #expect(math.day(containing: date).description == c.expected.day)
    #expect(math.week(containing: date).description == c.expected.week)
    #expect(math.hour(of: date) == c.expected.hour)
  }

  @Test func dayStartIsTheResetHourEvenAcrossDST() throws {
    let math = DayMath(
      timeZone: try #require(TimeZone(identifier: "America/Toronto")), resetHour: 4)
    let start = math.start(of: TollDay(year: 2026, month: 11, day: 1))
    #expect(Fixtures.instant("2026-11-01T09:00:00Z") == start)
    #expect(math.end(of: TollDay(year: 2026, month: 10, day: 31)) == start)
  }

  @Test func dayArithmeticCrossesMonthsAndYears() {
    let day = TollDay(year: 2026, month: 12, day: 31)
    #expect(day.adding(days: 1).description == "2027-01-01")
    #expect(day.adding(days: -365).description == "2025-12-31")
    #expect(TollDay(year: 2028, month: 2, day: 28).adding(days: 1).description == "2028-02-29")
    #expect(day.days(until: TollDay(year: 2027, month: 1, day: 4)) == 4)
    #expect(TollDay(year: 2026, month: 11, day: 15).weekStart.description == "2026-11-09")
  }
}
