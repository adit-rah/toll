import Foundation
import Testing

@testable import TollCore

/// Your sleep's ranges (the audit): read from every ended night, the night log's included, so
/// 30 days and All time count more than the transition log's ten or so nights.
struct InsightsSnapshotTests {
  let sleep = BlockID("sleep")

  func line(
    _ at: Date, _ cause: ReconcileCause, active: [BlockID], door: Door.Phase? = nil
  ) -> Transition {
    Transition(
      at: at, cause: cause, blockOn: !active.isEmpty, changed: true, home: true, inWindow: true,
      entitled: true, door: door, active: active)
  }

  /// The night on 10:30 pm to 7 am, with a tap at 11 pm each night.
  func log(_ days: ClosedRange<Int>) -> [Transition] {
    days.flatMap {
      [
        line(date(2026, 11, $0, 22, 30), .windowStart, active: [sleep]),
        line(date(2026, 11, $0, 23), .blockScreen, active: [sleep]),
        line(date(2026, 11, $0 + 1, 7), .windowEnd, active: []),
      ]
    }
  }

  /// Recorded nights in October, before the transition log's first line: 8 h 30 m each, a tap at
  /// midnight.
  func recorded(_ days: ClosedRange<Int>) -> [PastNight] {
    days.map { day in
      PastNight(
        night: date(2026, 10, day, 0), ran: true, start: date(2026, 10, day, 22, 30),
        end: date(2026, 10, day + 1, 7), locked: 8.5 * 3600, taps: [date(2026, 10, day + 1, 0)])
    }
  }

  var state: DuskState {
    var s = setUp()
    s.setupFinishedAt = date(2026, 10, 1, 12)
    return s
  }

  func insights(
    _ range: InsightsSnapshot.Range, history: [PastNight], log: [Transition],
    now: Date = date(2026, 11, 20, 9)
  ) -> InsightsSnapshot {
    let sleep = YourSleep(state: state, log: log, history: history, now: now, calendar: london)
    return InsightsSnapshot(
      nights: sleep.past, hours: sleep.hours, now: now, calendar: london, range: range)
  }

  /// 25 recorded nights and nine in the log: All time is all of them, 30 days the last 30.
  @Test func longRangesReadTheNightLog() {
    let all = insights(.all, history: recorded(1...25), log: log(11...19))
    #expect(all.nights == 34)
    #expect(all.hoursBlocked == Int(34 * 8.5))
    #expect(all.taps == 34)
    #expect(all.byHour[1] == 9 && all.byHour[2] == 25)
    #expect(all.peakHour == 0)
    // Nov 19's night and the 29 before it: from Oct 21's.
    let month = insights(.month, history: recorded(1...25), log: log(11...19))
    #expect(month.nights == 14)
    let week = insights(.week, history: recorded(1...25), log: log(11...19))
    #expect(week.nights == 7)
    #expect(week.hoursBlocked == Int(7 * 8.5))
  }

  /// A night in both counts once, as the record says.
  @Test func aRecordedNightCountsOnce() {
    let night = PastNight(
      night: date(2026, 11, 18, 0), ran: true, start: date(2026, 11, 18, 22, 30),
      end: date(2026, 11, 19, 7), locked: 8.5 * 3600, taps: [date(2026, 11, 18, 23)])
    let both = insights(.all, history: [night], log: log(17...19))
    #expect(both.nights == 3)
    #expect(both.taps == 3)
  }

  /// Records written before they kept the locked time or the taps: first-on to last-off stands in,
  /// and the transition log fills in the taps while it has them.
  @Test func olderRecordsStillCount() {
    let old = PastNight(
      night: date(2026, 11, 19, 0), ran: true, start: date(2026, 11, 19, 22, 30),
      end: date(2026, 11, 20, 7))
    let insights = insights(.all, history: [old], log: log(19...19))
    #expect(insights.hoursBlocked == 8)
    #expect(insights.taps == 1)
  }

  /// Study's hours aren't the night's, and a pause isn't locked.
  @Test func onlyTheNightLockedCounts() throws {
    let study = BlockID("study")
    let log = [
      line(date(2026, 11, 16, 9), .windowStart, active: [study]),
      line(date(2026, 11, 16, 17), .windowEnd, active: []),
      line(date(2026, 11, 16, 22, 30), .windowStart, active: [sleep]),
      line(date(2026, 11, 17, 1), .doorStart, active: [sleep], door: .open),
      line(date(2026, 11, 17, 1, 30), .doorEnd, active: [sleep]),
      line(date(2026, 11, 17, 7), .windowEnd, active: []),
      line(date(2026, 11, 17, 9), .windowStart, active: [study]),
      line(date(2026, 11, 17, 11), .windowEnd, active: []),
    ]
    let night = try #require(
      NightFacts.ended(
        log: log, sleep: sleepBlock(), since: date(2026, 11, 16, 12), now: date(2026, 11, 17, 12),
        calendar: london
      ).first)
    #expect(night.locked == 8 * 3600)
    let all = insights(.all, history: [], log: log, now: date(2026, 11, 17, 12))
    #expect(all.hoursBlocked == 8)
    #expect(all.nights == 1)
  }

  /// The chart covers the night's own hours: a 12:30 – 8:30 am night keeps its 8 am taps.
  @Test func theChartFitsTheNight() {
    let late = WeeklySchedule.everyDay(TimeWindow(start: time(0, 30), end: time(8, 30)))
    let hours = InsightsSnapshot.NightHours(late)
    #expect(hours.first == 0 && hours.count == 9 && hours.last == 8)
    #expect(InsightsSnapshot.NightHours(.everyDay(usual)) == .standard)
    let night = PastNight(
      night: date(2026, 11, 18, 0), ran: true, locked: 8 * 3600,
      taps: [date(2026, 11, 19, 8, 10), date(2026, 11, 19, 8, 20)])
    let insights = InsightsSnapshot(
      nights: [night], hours: hours, now: date(2026, 11, 19, 12), calendar: london, range: .all)
    #expect(insights.byHour[8] == 2)
    #expect(insights.peakHour == 8)
  }

  /// The record keeps what the ranges need, and reads it back.
  @Test func theRecordKeepsLockedTimeAndTaps() throws {
    let facts = try #require(
      NightFacts.ended(
        log: log(16...16), sleep: sleepBlock(), since: date(2026, 11, 16, 12),
        now: date(2026, 11, 17, 9), calendar: london
      ).first)
    let line = try #require(NightRecordLine.encode(facts, calendar: london, model: stamp))
    let past = try #require(NightRecordLine.past(line, calendar: london))
    #expect(past.locked == 8.5 * 3600)
    #expect(past.taps == [date(2026, 11, 16, 23)])
    #expect(past.start == date(2026, 11, 16, 22, 30) && past.end == date(2026, 11, 17, 7))
  }

  @Test func nothingYet() {
    #expect(insights(.all, history: [], log: []).isEmpty)
  }
}
