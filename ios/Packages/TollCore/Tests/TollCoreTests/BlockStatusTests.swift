import Foundation
import Testing

@testable import TollCore

struct BlockStatusTests {
  static let zone = TimeZone(identifier: "America/Toronto") ?? .gmt
  let math = DayMath(timeZone: zone, resetHour: 4)

  /// 2026-11-13 is a Friday in Toronto. Clocks go forward on 8 March and back on 1 November.
  func local(_ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
    math.calendar.date(
      from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))
      ?? .distantPast
  }

  func utc(_ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    return calendar.date(
      from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))
      ?? .distantPast
  }

  func phase(_ schedule: Schedule, _ date: Date, sessions: [ActiveSession] = []) -> BlockPhase {
    BlockStatus.phase(
      of: BlockDefinition(id: "b1", appRefs: ["ig", "tt"], schedule: schedule),
      sessions: sessions, at: date, math: math)
  }

  @Test func alwaysIsOnWithNoEnd() {
    #expect(Schedule.always.nextTransition(after: local(11, 13, 12), in: math) == nil)
    #expect(phase(.always, local(11, 13, 12)) == .on(until: nil))
  }

  @Test func anOvernightFridayWindowRunsIntoSaturday() {
    let friday = Schedule.custom(
      start: ClockTime(hour: 22), end: ClockTime(hour: 2), days: [.friday])
    #expect(phase(friday, local(11, 13, 12)) == .off(from: local(11, 13, 22)))
    #expect(phase(friday, local(11, 13, 23)) == .on(until: local(11, 14, 2)))
    #expect(phase(friday, local(11, 14, 1, 59)) == .on(until: local(11, 14, 2)))
    #expect(phase(friday, local(11, 14, 2)) == .off(from: local(11, 20, 22)))
    #expect(phase(friday, local(11, 14, 23)) == .off(from: local(11, 20, 22)))
  }

  @Test func weekdaysOnFridayEveningStartAgainOnMonday() {
    let weekdays = Schedule.preset(.weekdays)
    #expect(phase(weekdays, local(11, 13, 10)) == .on(until: local(11, 13, 17)))
    #expect(phase(weekdays, local(11, 13, 18)) == .off(from: local(11, 16, 9)))
    #expect(phase(weekdays, local(11, 15, 9)) == .off(from: local(11, 16, 9)))
  }

  @Test func nightsEveryDay() {
    let nights = Schedule.preset(.nights)
    #expect(phase(nights, local(11, 13, 7)) == .off(from: local(11, 13, 23)))
    #expect(phase(nights, local(11, 13, 23)) == .on(until: local(11, 14, 7)))
    #expect(phase(nights, local(11, 14, 0)) == .on(until: local(11, 14, 7)))
  }

  @Test func equalStartAndEndCoversWholeDays() {
    let nine = ClockTime(hour: 9)
    let weekend = Schedule.custom(start: nine, end: nine, days: [.saturday, .sunday])
    #expect(phase(weekend, local(11, 13, 12)) == .off(from: local(11, 14, 0)))
    #expect(phase(weekend, local(11, 14, 12)) == .on(until: local(11, 16, 0)))
    #expect(
      phase(.custom(start: nine, end: nine, days: Weekday.all), local(11, 14, 12))
        == .on(until: nil))
    #expect(
      phase(.custom(start: nine, end: ClockTime(hour: 17), days: []), local(11, 14, 12))
        == .off(from: nil))
  }

  @Test func nightsKeepTheirClockTimesWhenTheClocksChange() {
    let nights = Schedule.preset(.nights)
    #expect(phase(nights, local(3, 7, 23, 30)) == .on(until: local(3, 8, 7)))
    #expect(local(3, 8, 7).timeIntervalSince(local(3, 7, 23)) == 7 * 3600)
    #expect(phase(nights, local(10, 31, 23, 30)) == .on(until: local(11, 1, 7)))
    #expect(local(11, 1, 7).timeIntervalSince(local(10, 31, 23)) == 9 * 3600)
    #expect(phase(nights, local(11, 1, 12)) == .off(from: local(11, 1, 23)))
  }

  @Test func aStartInsideTheMissingHourFallsOnTheFirstMinuteThatExists() {
    let early = Schedule.custom(
      start: ClockTime(hour: 2, minute: 30), end: ClockTime(hour: 5), days: Weekday.all)
    // 02:00–03:00 does not exist on 8 March; 03:00 EDT is 07:00 UTC.
    #expect(phase(early, local(3, 8, 0)) == .off(from: utc(3, 8, 7)))
    #expect(early.isActive(at: utc(3, 8, 7), in: math))
    #expect(phase(early, utc(3, 8, 7)) == .on(until: local(3, 8, 5)))
  }

  @Test func theRepeatedHourFollowsWhatIsActiveSays() {
    let late = Schedule.custom(
      start: ClockTime(hour: 22), end: ClockTime(hour: 1, minute: 30), days: Weekday.all)
    // 1 November: 01:30 EDT is 05:30 UTC; the clock then reads 01:00 again at 06:00 UTC.
    #expect(phase(late, utc(11, 1, 4, 30)) == .on(until: utc(11, 1, 5, 30)))
    var date = utc(11, 1, 4, 30)
    var edges: [Date] = []
    while let next = late.nextTransition(after: date, in: math), edges.count < 4 {
      #expect(late.isActive(at: next, in: math) != late.isActive(at: date, in: math))
      #expect(
        late.isActive(at: next.addingTimeInterval(-60), in: math)
          == late.isActive(at: date, in: math))
      edges.append(next)
      date = next
    }
    #expect(edges == [utc(11, 1, 5, 30), utc(11, 1, 6), utc(11, 1, 6, 30), local(11, 1, 22)])
  }

  @Test func aLiveSessionOpensTheBlockUntilItExpires() {
    let now = local(11, 13, 12)
    let session = ActiveSession(appRefs: ["tt"], minutes: 10, startedAt: now)
    let other = ActiveSession(appRefs: ["yt"], minutes: 15, startedAt: now)
    #expect(
      phase(.always, now.addingTimeInterval(60), sessions: [session, other])
        == .open(until: session.expiresAt))
    #expect(phase(.always, session.expiresAt, sessions: [session, other]) == .on(until: nil))
    #expect(phase(.always, now, sessions: [other]) == .on(until: nil))
  }

  @Test func aSessionThatOutlivesTheWindowEndsWithIt() {
    let nights = Schedule.preset(.nights)
    let session = ActiveSession(appRefs: ["ig"], minutes: 15, startedAt: local(11, 14, 6, 55))
    #expect(
      phase(nights, local(11, 14, 6, 58), sessions: [session]) == .open(until: local(11, 14, 7)))
    #expect(
      phase(nights, local(11, 14, 7, 2), sessions: [session]) == .off(from: local(11, 14, 23)))
  }

  @Test func theWordsBesideABlock() {
    #expect(Copy.ActiveBlock.left(seconds: 402) == "6:42 left")
    #expect(Copy.ActiveBlock.left(seconds: 5) == "0:05 left")
    #expect(Copy.ActiveBlock.left(seconds: 900) == "15:00 left")
    #expect(Copy.ActiveBlock.until(math.clockTime(of: local(11, 14, 7))) == "Until 7 am")
    #expect(Copy.ActiveBlock.starts(ClockTime(hour: 23)) == "Starts 11 pm")
    #expect(Copy.ActiveBlock.blocksOn(1) == "1 block on")
    #expect(Copy.ActiveBlock.blocksOn(3) == "3 blocks on")
    #expect(Copy.SessionPicker.unblock(minutes: 10) == "Unblock for 10 min")
    #expect(
      Copy.Home.sessionActive("Instagram", minutesLeft: 7) == "Instagram is open · 7 min left")
  }
}
