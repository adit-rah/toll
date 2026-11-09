import Foundation
import Testing

@testable import TollCore

/// Fixture event logs built in code: the 04:00 boundary, a DST week, empty ranges, tag grouping.
struct MetricsEngineTests {
  let zone = TimeZone(identifier: "America/Toronto") ?? .gmt
  var math: DayMath { DayMath(timeZone: zone, resetHour: 4) }
  var engine: MetricsEngine { MetricsEngine(math: math, config: .defaults) }

  func at(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int = 0, _ s: Int = 0) -> Date {
    math.calendar.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi, second: s)) ?? .distantPast
  }

  func e(_ kind: GateEvent.Kind, _ date: Date, app: AppRef? = "ig", free: Bool? = nil, wait: Int? = nil, session: Int? = nil)
    -> GateEvent
  {
    GateEvent(kind: kind, occurredAt: date, tzOffsetMinutes: -300, appRef: app, free: free, waitMinutes: wait, sessionMinutes: session)
  }

  let monday = TollDay(year: 2026, month: 11, day: 9)

  @Test func aDayRunsFromFourToFour() {
    let events = [
      e(.pass, at(2026, 11, 9, 3, 59), free: true),
      e(.pass, at(2026, 11, 9, 4, 0), free: true),
      e(.pass, at(2026, 11, 10, 3, 30), free: false, wait: 3),
    ]
    let days = engine.days(events, from: monday.adding(days: -1), through: monday)
    #expect(days.map(\.passes) == [1, 2])
    let m = engine.metrics(events, from: monday, through: monday)
    #expect(m.passes == 2 && m.free == 1 && m.waited == 1 && m.waitMinutes == 3)
    #expect(m.latePasses == 1)
  }

  @Test func heldCountsWalkAwaysOnly() {
    let t = at(2026, 11, 9, 12)
    let events = [
      e(.blockHit, t),
      e(.blockHit, t.addingTimeInterval(600)),
      e(.waitStarted, t.addingTimeInterval(610), wait: 3),
      e(.blockHit, t.addingTimeInterval(1200)),
      e(.pass, t.addingTimeInterval(1205), free: true),
      e(.waitAbandoned, t.addingTimeInterval(700)),
    ]
    let m = engine.metrics(events, from: monday, through: monday)
    #expect(m.hits == 3 && m.held == 1 && m.abandoned == 1)
    #expect(m.heldPercent == 33)
  }

  @Test func cleanDaysAreActiveDaysWithoutPasses() {
    let events = [
      e(.checkin, at(2026, 11, 9, 9)),
      e(.checkin, at(2026, 11, 10, 9)),
      e(.pass, at(2026, 11, 10, 20), free: true),
      e(.blockHit, at(2026, 11, 11, 20)),
    ]
    let m = engine.metrics(events, from: monday, through: monday.adding(days: 6))
    #expect(m.activeDays == 3 && m.cleanDays == 2)
  }

  @Test func emptyRangesAreZeroNotNil() {
    let m = engine.metrics([], from: monday, through: monday.adding(days: 6))
    #expect(m.passes == 0 && m.heldPercent == nil && m.lateShare == nil)
    #expect(engine.days([], from: monday, through: monday.adding(days: 6)).count == 7)
  }

  @Test func tagsGroupPassesAndWaitMinutes() {
    let events = [
      e(.pass, at(2026, 11, 9, 12), app: "ig", free: false, wait: 5),
      e(.pass, at(2026, 11, 9, 13), app: "ig", free: false, wait: 8),
      e(.pass, at(2026, 11, 9, 14), app: "tt", free: true),
      e(.pass, at(2026, 11, 9, 15), app: "unknown", free: true),
    ]
    let m = engine.metrics(events, from: monday, through: monday, tags: ["ig": .instagram, "tt": .tiktok])
    #expect(m.byTag[.instagram] == Metrics.TagMetrics(passes: 2, waitMinutes: 13))
    #expect(m.byTag[.tiktok]?.passes == 1)
    #expect(m.byTag[nil]?.passes == 1)
  }

  @Test func theDSTWeekKeepsSevenDaysAndLocalHours() {
    let dstMonday = TollDay(year: 2026, month: 10, day: 26)
    let events = [
      e(.pass, at(2026, 11, 1, 1, 30), free: true),
      e(.pass, at(2026, 11, 1, 23, 30), free: true),
    ]
    let days = engine.days(events, from: dstMonday, through: dstMonday.adding(days: 6))
    #expect(days.count == 7)
    #expect(days.map(\.passes) == [0, 0, 0, 0, 0, 1, 1])
    let m = engine.metrics(events, from: dstMonday, through: dstMonday.adding(days: 6))
    #expect(m.byHour[1] == 1 && m.byHour[23] == 1 && m.latePasses == 2)
  }

  @Test func sessionChoicesAndTrend() {
    let events = [
      e(.sessionEnded, at(2026, 11, 9, 12), session: 5), e(.sessionEnded, at(2026, 11, 9, 13), session: 5),
      e(.sessionEnded, at(2026, 11, 9, 14), session: 15),
    ]
    #expect(engine.metrics(events, from: monday, through: monday).sessionChoices == [5: 2, 15: 1])
    #expect(MetricsEngine.trend(this: 11, last: 17).map { ($0 * 100).rounded() } == -35)
    #expect(MetricsEngine.trend(this: 3, last: 0) == nil)
  }

  @Test func weekdayAveragesAndHistory() {
    let events = [
      e(.pass, at(2026, 11, 9, 12), free: true), e(.pass, at(2026, 11, 16, 12), free: true),
      e(.pass, at(2026, 11, 16, 13), free: true),
    ]
    let averages = engine.weekdayAverages(events, weeks: [monday, monday.adding(days: 7)])
    #expect(averages[.monday] == 1.5 && averages[.tuesday] == 0)
    #expect(engine.dailyHistory(events, before: monday.adding(days: 8), days: 28) == [1, 2])
  }
}
