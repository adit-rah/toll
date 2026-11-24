import Foundation
import Testing

@testable import TollCore

/// Your sleep (D65, #103): a count that only goes up, the week as dots, a personal best only when
/// it's better than the person's own past, and Monday's new week.
struct YourSleepTests {
  let sleep = BlockID("sleep")

  func line(_ at: Date, _ cause: ReconcileCause, active: [BlockID], home: Bool? = true)
    -> Transition
  {
    Transition(
      at: at, cause: cause, blockOn: !active.isEmpty, changed: false, home: home,
      inWindow: true, entitled: true, active: active)
  }

  /// The block on at 10:30 pm on each of these November days, off at 7 am.
  func nights(_ days: [Int]) -> [Transition] {
    days.flatMap {
      [
        line(date(2026, 11, $0, 22, 30), .windowStart, active: [sleep]),
        line(date(2026, 11, $0 + 1, 7), .windowEnd, active: []),
      ]
    }
  }

  func past(_ days: [Int], ran: Bool = true) -> [PastNight] {
    days.map { PastNight(night: date(2026, 11, $0, 0), ran: ran) }
  }

  var state: DuskState {
    var s = setUp()
    s.setupFinishedAt = date(2026, 10, 30, 12)
    return s
  }

  func sleep(_ now: Date, log: [Transition], history: [PastNight] = []) -> YourSleep {
    YourSleep(state: state, log: log, history: history, now: now, calendar: london)
  }

  /// The night log keeps what the transition log trims, and a night in both counts once.
  @Test func theCountOnlyGoesUp() {
    let history = past([2, 3, 4, 5, 6]) + past([7], ran: false) + past([18])
    let now = date(2026, 11, 20, 15)
    #expect(sleep(now, log: nights([17, 18, 19]), history: history).nights == "8 nights locked")
    #expect(sleep(now, log: [], history: history).nights == "6 nights locked")
    #expect(sleep(now, log: [], history: []).nights == nil)
  }

  /// Monday morning: last week in one line, then seven empty dots.
  @Test func mondayIsANewWeek() {
    var log = nights([16, 17, 18, 20, 21, 22])
    log.append(line(date(2026, 11, 19, 22, 30), .windowStart, active: [], home: false))
    let monday = sleep(date(2026, 11, 23, 9), log: log)
    #expect(monday.weekTitle == "A new week")
    #expect(monday.lastWeek == "6 nights last week")
    #expect(monday.dots.count == 7)
    #expect(monday.dots.allSatisfy { $0.dot == .ahead })
    #expect(monday.best == nil)
    // Sunday's night, still on at 1 am, belongs to last week.
    let sunday = sleep(date(2026, 11, 23, 1), log: log)
    #expect(sunday.weekTitle == "This week")
    #expect(sunday.dots.first?.day == "Mon")
    #expect(sunday.dots.filter { $0.dot == .ran }.count == 6)
    #expect(sunday.dots[3].dot == .hollow(.away))
  }

  /// Most nights in a week, only when it's more than every week before.
  @Test func aPersonalBestOnlyWhenBetter() {
    // Weeks of Nov 2 (4 nights) and Nov 9 (5 nights) in the night log.
    let history = past([2, 3, 4, 5]) + past([9, 10, 11, 12, 13])
    let sunday = date(2026, 11, 22, 9)
    let six = sleep(sunday, log: nights([16, 17, 18, 19, 20, 21]), history: history)
    #expect(six.best == .init(title: "Your most in a week", detail: "6 nights this week"))
    #expect(sleep(sunday, log: nights([16, 17, 18, 19, 20]), history: history).best == nil)
    // Nothing to compare with: no best.
    #expect(sleep(sunday, log: nights([16, 17, 18, 19, 20, 21])).best == nil)
  }

  /// The free week stands still after the trial (#48).
  @Test func afterTheTrialTheFreeWeek() {
    var s = state
    s.trial.start = date(2026, 10, 30, 12)
    s.trial.entitled = false
    let week = YourSleep(
      state: s, log: [], history: [], now: date(2026, 11, 20, 15), calendar: london)
    #expect(week.weekTitle == "Your free week")
    #expect(week.best == nil && week.lastWeek == nil)
  }

  @Test func theNightLogReadsBack() throws {
    let facts = try #require(
      NightFacts.ended(
        log: nights([16]), sleep: sleepBlock(), since: date(2026, 11, 16, 12),
        now: date(2026, 11, 17, 9), calendar: london
      ).first)
    let line = try #require(NightRecordLine.encode(facts, calendar: london))
    let past = try #require(NightRecordLine.past(line, calendar: london))
    #expect(past.night == date(2026, 11, 16, 0) && past.ran)
  }
}
