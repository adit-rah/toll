import Foundation
import Testing

@testable import TollCore

struct InsightsSnapshotTests {
  func line(_ at: Date, _ cause: ReconcileCause, on: Bool, changed: Bool) -> Transition {
    Transition(
      at: at, cause: cause, blockOn: on, changed: changed, home: true, inWindow: true,
      entitled: true)
  }

  /// Two weeks: nightly 22:30–07:00 blocks; four taps a night in week one, one in week two.
  var log: [Transition] {
    var lines: [Transition] = []
    for day in 2...15 {
      lines.append(line(date(2026, 11, day, 22, 30), .windowStart, on: true, changed: true))
      for tap in 0..<(day <= 8 ? 4 : 1) {
        lines.append(
          line(date(2026, 11, day, 23, tap * 10), .blockScreen, on: true, changed: false))
      }
      lines.append(line(date(2026, 11, day + 1, 7), .windowEnd, on: false, changed: true))
    }
    return lines
  }

  @Test func allOfIt() {
    let insights = InsightsSnapshot(
      log: log, now: date(2026, 11, 16, 12), calendar: london, range: .all)
    #expect(insights.nights == 14)
    #expect(insights.since == date(2026, 11, 2, 0))
    #expect(insights.hoursBlocked == 14 * 8 + 7)
    #expect(insights.weeks == [28, 7])
    #expect(insights.change == -75)
    #expect(insights.byHour[1] == 35)
    #expect(insights.peakHour == 23)
  }

  @Test func aWeek() {
    let insights = InsightsSnapshot(
      log: log, now: date(2026, 11, 16, 12), calendar: london, range: .week)
    #expect(insights.nights == 7)
  }

  @Test func nothingYet() {
    #expect(
      InsightsSnapshot(log: [], now: date(2026, 11, 16, 12), calendar: london, range: .all).isEmpty)
  }
}
