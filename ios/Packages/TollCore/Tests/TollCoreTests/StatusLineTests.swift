import Foundation
import Testing

@testable import TollCore

struct StatusLineTests {
  func line(_ state: DuskState, _ now: Date) -> StatusLine {
    StatusLine(state: state, now: now, calendar: london)
  }

  @Test func blockedShowsTheEnd() {
    var s = setUp()
    run(&s, date(2026, 11, 17, 23))
    #expect(line(s, date(2026, 11, 17, 23)) == .blocked(until: date(2026, 11, 18, 7)))
  }

  @Test func awayInsideTheWindow() {
    #expect(line(setUp(home: false), date(2026, 11, 17, 23)) == .away)
  }

  @Test func awayInTheDayShowsTonight() {
    #expect(
      line(setUp(home: false), date(2026, 11, 17, 15))
        == .starts(at: date(2026, 11, 17, 22, 30), scheduleOnly: false))
  }

  @Test func withoutLocationTheHomeConditionGoes() {
    var s = setUp(home: false)
    s.location = .scheduleOnly
    #expect(
      line(s, date(2026, 11, 18, 8)) == .starts(at: date(2026, 11, 18, 22, 30), scheduleOnly: true))
  }

  @Test func staleBlockIsNotShownAsBlocked() {
    var s = setUp()
    run(&s, date(2026, 11, 17, 23))
    #expect(
      line(s, date(2026, 11, 18, 7, 30))
        == .starts(at: date(2026, 11, 18, 22, 30), scheduleOnly: false))
  }
}
