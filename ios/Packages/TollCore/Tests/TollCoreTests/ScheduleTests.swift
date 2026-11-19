import Foundation
import Testing

@testable import TollCore

/// Weekly schedules: rules start on their days and may cross midnight (D29).
struct ScheduleTests {
  /// School nights 10:30 pm to 7:00 am; Friday and Saturday nights 11:30 pm to 9:30 am.
  let split = WeeklySchedule(rules: [
    .init(days: Weekday.schoolNights, window: usual),
    .init(days: Weekday.weekendNights, window: TimeWindow(start: time(23, 30), end: time(9, 30))),
  ])

  @Test func weekdaysFromTheCalendar() {
    #expect(Weekday(of: date(2026, 11, 16, 12), calendar: london) == .monday)
    #expect(Weekday(of: date(2026, 11, 22, 12), calendar: london) == .sunday)
  }

  @Test func aNightBelongsToTheDayItStarts() {
    // Thursday 11 pm: a school night.
    #expect(split.occurrence(containing: date(2026, 11, 19, 23), calendar: london) != nil)
    // Friday 11 pm: the weekend rule starts at 11:30.
    #expect(split.occurrence(containing: date(2026, 11, 20, 23), calendar: london) == nil)
    // Friday's night runs into Saturday morning.
    let friday = split.occurrence(containing: date(2026, 11, 21, 8), calendar: london)
    #expect(friday?.start == date(2026, 11, 20, 23, 30))
    #expect(friday?.end == date(2026, 11, 21, 9, 30))
    // Sunday 11 pm, a school night, runs to Monday 7:00.
    #expect(
      split.occurrence(containing: date(2026, 11, 23, 6), calendar: london)?.end
        == date(2026, 11, 23, 7))
  }

  @Test func nextStartSkipsDaysWithoutARule() {
    let weekdays = WeeklySchedule(rules: [
      .init(days: Weekday.weekdays, window: TimeWindow(start: time(9), end: time(17)))
    ])
    #expect(
      weekdays.nextStart(after: date(2026, 11, 20, 18), calendar: london) == date(2026, 11, 23, 9))
    #expect(
      weekdays.lastEnd(atOrBefore: date(2026, 11, 22, 12), calendar: london)
        == date(2026, 11, 20, 17))
  }

  @Test func endsAcrossAWeek() {
    let ends = split.ends(
      after: date(2026, 11, 16, 12), through: date(2026, 11, 23, 12), calendar: london)
    #expect(ends.count == 7)
    #expect(ends.first == date(2026, 11, 17, 7))
    #expect(ends.contains(date(2026, 11, 21, 9, 30)))
  }

  @Test func emptyDaysAreInvalid() {
    #expect(!WeeklySchedule(rules: [.init(days: [], window: usual)]).isValid)
    #expect(!WeeklySchedule(rules: []).isValid)
    #expect(WeeklySchedule.everyDay(usual).isValid)
  }
}
