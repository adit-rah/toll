import Foundation
import Testing

@testable import TollCore

/// Settings' appearance (D36) and "Dark in the evening": dark from the sky's evening hour until its
/// morning, whatever was chosen, when it's on.
struct AppearanceTests {
  let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/London") ?? .gmt
    return calendar
  }()

  func at(_ hour: Int, _ minute: Int = 0, day: Int = 10, month: Int = 6) throws -> Date {
    try #require(
      calendar.date(
        from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute)))
  }

  /// 4 pm until 5 am, the sky's evening and morning hours.
  @Test(arguments: [
    (15, 59, false), (16, 0, true), (21, 30, true), (0, 0, true), (4, 59, true), (5, 0, false),
    (12, 0, false),
  ])
  func eveningHours(_ hour: Int, _ minute: Int, _ evening: Bool) throws {
    #expect(Appearance.isEvening(at: try at(hour, minute), calendar: calendar) == evening)
  }

  @Test func eachChoiceByDayAndEvening() throws {
    let day = try at(11)
    let evening = try at(20)
    #expect(Appearance.dark.scheme(at: day, darkInEvening: false, calendar: calendar) == .dark)
    #expect(Appearance.light.scheme(at: day, darkInEvening: true, calendar: calendar) == .light)
    #expect(Appearance.system.scheme(at: day, darkInEvening: true, calendar: calendar) == nil)
    #expect(Appearance.light.scheme(at: evening, darkInEvening: true, calendar: calendar) == .dark)
    #expect(Appearance.system.scheme(at: evening, darkInEvening: true, calendar: calendar) == .dark)
    #expect(
      Appearance.light.scheme(at: evening, darkInEvening: false, calendar: calendar) == .light)
    #expect(Appearance.system.scheme(at: evening, darkInEvening: false, calendar: calendar) == nil)
  }

  /// The hours come from the sky's, so moving the evening light moves the dark with it.
  @Test func followsTheSkysHours() throws {
    var config = TollConfig()
    config.sky.eveningFromHour = 19
    config.sky.morningFromHour = 6
    #expect(!Appearance.isEvening(at: try at(18), calendar: calendar, config: config))
    #expect(Appearance.isEvening(at: try at(5, 30), calendar: calendar, config: config))
  }

  @Test func nextChangeIsTheNearerBoundary() throws {
    #expect(Appearance.nextChange(after: try at(11), calendar: calendar) == (try at(16)))
    #expect(Appearance.nextChange(after: try at(16), calendar: calendar) == (try at(5, day: 11)))
    #expect(Appearance.nextChange(after: try at(2), calendar: calendar) == (try at(5)))
  }

  /// The clocks go forward at 1 am in London on 29 March 2026: the morning still comes at 5.
  @Test func nextChangeAcrossTheClockChange() throws {
    let night = try at(0, 30, day: 29, month: 3)
    #expect(
      Appearance.nextChange(after: night, calendar: calendar) == (try at(5, day: 29, month: 3)))
  }
}
