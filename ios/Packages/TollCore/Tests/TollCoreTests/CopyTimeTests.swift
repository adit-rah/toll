import Foundation
import Testing

@testable import TollCore

@Suite struct CopyTimeTests {
  func calendar(_ locale: String) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: locale)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
    return calendar
  }

  /// iOS and ICU put a narrow no-break space before am/pm; the canvas draws a plain one.
  func plain(_ text: String) -> String { text.replacingOccurrences(of: "\u{202F}", with: " ") }

  @Test func twelveHourPhonesReadLowercaseAndShortWholeHours() {
    let us = calendar("en_US")
    #expect(plain(Copy.time(ClockTime(hour: 22, minute: 30), in: us)) == "10:30 pm")
    #expect(plain(Copy.time(ClockTime(hour: 9), in: us, short: true)) == "9 am")
    let study = TimeWindow(start: ClockTime(hour: 9), end: ClockTime(hour: 17))
    #expect(plain(Copy.span(study, in: us, short: true)) == "9 am – 5 pm")
    let sleep = TimeWindow(start: ClockTime(hour: 22, minute: 30), end: ClockTime(hour: 7))
    #expect(plain(Copy.span(sleep, in: us, short: true)) == "10:30 pm – 7:00 am")
  }

  @Test func twentyFourHourPhonesKeepMinutes() {
    let gb = calendar("en_GB")
    #expect(plain(Copy.time(ClockTime(hour: 22, minute: 30), in: gb)) == "22:30")
    #expect(plain(Copy.time(ClockTime(hour: 9), in: gb, short: true)) == "09:00")
  }
}
