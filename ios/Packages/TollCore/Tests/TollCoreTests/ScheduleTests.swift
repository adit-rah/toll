import Foundation
import Testing

@testable import TollCore

struct ScheduleTests {
  let math = DayMath(timeZone: TimeZone(identifier: "America/Toronto") ?? .gmt, resetHour: 4)

  /// 2026-11-13 is a Friday in Toronto (EST, UTC−5).
  func local(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
    math.calendar.date(
      from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))
      ?? .distantPast
  }

  @Test func alwaysIsAlwaysActive() {
    #expect(Schedule.always.isActive(at: local(13, 3), in: math))
  }

  @Test func nightsCrossMidnight() {
    let nights = Schedule.preset(.nights)
    #expect(nights.crossesMidnight)
    #expect(nights.isActive(at: local(13, 23, 30), in: math))
    #expect(nights.isActive(at: local(14, 6, 59), in: math))
    #expect(!nights.isActive(at: local(14, 7), in: math))
    #expect(!nights.isActive(at: local(13, 22, 59), in: math))
  }

  @Test func weekdaysExcludeWeekendsAndTheEndMinute() {
    let weekdays = Schedule.preset(.weekdays)
    #expect(weekdays.isActive(at: local(13, 9), in: math))
    #expect(!weekdays.isActive(at: local(13, 17), in: math))
    #expect(!weekdays.isActive(at: local(14, 10), in: math))
  }

  @Test func anOvernightWindowBelongsToTheDayItStarts() {
    let fridayNight = Schedule.custom(
      start: ClockTime(hour: 22), end: ClockTime(hour: 2), days: [.friday])
    #expect(fridayNight.isActive(at: local(14, 1), in: math))
    #expect(!fridayNight.isActive(at: local(15, 1), in: math))
    #expect(!fridayNight.isActive(at: local(13, 1), in: math))
  }

  @Test func scheduleEncodesClockTimesAsText() throws {
    let data = try JSONEncoder().encode(Schedule.preset(.nights))
    let text = String(decoding: data, as: UTF8.self)
    #expect(text.contains("\"23:00\"") && text.contains("\"07:00\""))
    #expect(try JSONDecoder().decode(Schedule.self, from: data) == Schedule.preset(.nights))
  }

  @Test func shieldPlanSubtractsLiveSessionsOnly() {
    let blocks = [
      BlockDefinition(id: "b1", appRefs: ["ig", "tt"], schedule: .always),
      BlockDefinition(id: "b2", appRefs: ["yt"], schedule: .preset(.weekdays)),
    ]
    let now = local(14, 10)
    let live = ActiveSession(appRefs: ["ig"], minutes: 5, startedAt: now, windowMinutes: 60)
    let old = ActiveSession(
      appRefs: ["tt"], minutes: 5, startedAt: now.addingTimeInterval(-7200), windowMinutes: 60)
    let plan = ShieldPlan.make(blocks: blocks, sessions: [live, old], at: now, math: math)
    #expect(plan.shielded == ["tt"])
    #expect(plan.unlocked == ["ig"])
  }
}
