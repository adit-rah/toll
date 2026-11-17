import Foundation

@testable import TollCore

func calendar(_ zone: String) -> Calendar {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(identifier: zone) ?? .gmt
  return calendar
}

func date(
  _ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0,
  in zone: String = "Europe/London"
) -> Date {
  calendar(zone).date(
    from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))
    ?? .distantPast
}

func time(_ hour: Int, _ minute: Int = 0) -> ClockTime { ClockTime(hour: hour, minute: minute) }

/// 10:30 pm to 7:00 am, the spec's example night.
let usual = SleepWindow(start: time(22, 30), end: time(7))
