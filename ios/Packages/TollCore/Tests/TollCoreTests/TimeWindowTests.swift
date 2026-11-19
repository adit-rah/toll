import Foundation
import Testing

@testable import TollCore

struct TimeWindowTests {
  @Test func startIsWakeMinusLead() {
    #expect(TimeWindow(wake: time(7), leadHours: 8.5) == usual)
    #expect(TimeWindow(wake: time(6, 15), leadHours: 8.5).start == time(21, 45))
    #expect(TimeWindow(wake: time(3), leadHours: 8.5).start == time(18, 30))
    #expect(TimeWindow(wake: time(11), leadHours: 8.5).start == time(2, 30))
  }

  @Test func crossesMidnight() {
    let cases: [(Date, Bool)] = [
      (date(2026, 11, 17, 22, 29), false),
      (date(2026, 11, 17, 22, 30), true),
      (date(2026, 11, 18, 0, 0), true),
      (date(2026, 11, 18, 6, 59), true),
      (date(2026, 11, 18, 7, 0), false),
      (date(2026, 11, 18, 12, 0), false),
    ]
    for (moment, inside) in cases {
      #expect(usual.contains(moment, calendar: london) == inside)
    }
    let night = usual.night(containing: date(2026, 11, 18, 3), calendar: london)
    #expect(night?.start == date(2026, 11, 17, 22, 30))
    #expect(night?.end == date(2026, 11, 18, 7))
  }

  @Test func sameDayWindow() {
    let late = TimeWindow(start: time(1), end: time(9))
    #expect(!late.crossesMidnight)
    #expect(late.contains(date(2026, 11, 18, 1), calendar: london))
    #expect(!late.contains(date(2026, 11, 18, 0, 59), calendar: london))
    #expect(!late.contains(date(2026, 11, 18, 9), calendar: london))
  }

  @Test func tooShortIsNoWindow() {
    let short = TimeWindow(start: time(22), end: time(22, 10))
    #expect(!short.isValid)
    #expect(!short.contains(date(2026, 11, 17, 22, 5), calendar: london))
    #expect(!TimeWindow(start: time(22), end: time(22)).isValid)
  }

  @Test func springForwardNightIsAnHourShorter() {
    let night = usual.night(startingOn: date(2026, 3, 28, 12), calendar: london)
    #expect(night?.start == date(2026, 3, 28, 22, 30))
    #expect(night?.end == date(2026, 3, 29, 7))
    #expect(night.map { $0.end.timeIntervalSince($0.start) } == 7.5 * 3600)
  }

  @Test func fallBackNightIsAnHourLonger() {
    let night = usual.night(startingOn: date(2026, 10, 24, 12), calendar: london)
    #expect(night.map { $0.end.timeIntervalSince($0.start) } == 9.5 * 3600)
  }

  @Test func skippedStartBecomesTheFirstRealTime() {
    let window = TimeWindow(start: time(1, 30), end: time(8))
    let night = window.night(startingOn: date(2026, 3, 29, 12), calendar: london)
    #expect(night?.start == date(2026, 3, 29, 2))
  }

  @Test func repeatedStartIsTheFirst() {
    let window = TimeWindow(start: time(1, 30), end: time(8))
    let night = window.night(startingOn: date(2026, 10, 25, 12), calendar: london)
    #expect(night?.start == Date(timeIntervalSince1970: 1_792_888_200))
  }

  @Test func followsTheLocalClockAfterTravel() {
    let instant = date(2026, 11, 18, 4)
    #expect(usual.contains(instant, calendar: london))
    #expect(!usual.contains(instant, calendar: calendar("Asia/Tokyo")))
    #expect(usual.contains(instant, calendar: calendar("America/New_York")))
    #expect(!usual.contains(instant, calendar: calendar("America/Los_Angeles")))
  }

  @Test func lastEndAndNextStart() {
    let evening = date(2026, 11, 17, 20)
    #expect(usual.lastEnd(atOrBefore: evening, calendar: london) == date(2026, 11, 17, 7))
    #expect(usual.nextStart(after: evening, calendar: london) == date(2026, 11, 17, 22, 30))
    let night = date(2026, 11, 18, 1)
    #expect(usual.lastEnd(atOrBefore: night, calendar: london) == date(2026, 11, 17, 7))
    #expect(usual.nextStart(after: night, calendar: london) == date(2026, 11, 18, 22, 30))
    let end = date(2026, 11, 18, 7)
    #expect(usual.lastEnd(atOrBefore: end, calendar: london) == end)
  }
}
