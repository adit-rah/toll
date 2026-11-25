import Foundation
import Testing

@testable import TollCore

/// #144: the usual time asleep and awake from Health's nights, and suggestion v0 for the buffers'
/// targets. Sources are merged before anything is counted.
struct SleepEstimateTests {
  let config = TollConfig.defaults
  /// Wednesday 25 November 2026, 9 am: the estimate reads the four weeks before.
  let now = date(2026, 11, 25, 9)

  /// A night that starts on 11 November plus `day`, asleep at `asleep` minutes past 10 pm and up
  /// eight hours later.
  func night(
    _ day: Int, asleep: Int = 80, hours: Double = 8, inBed: Int? = nil,
    source: SleepSample.Source = .watch, id: String = "watch"
  ) -> [SleepSample] {
    let onset = date(2026, 11, day, 22).addingTimeInterval(TimeInterval(asleep * 60))
    var samples = [
      SleepSample(
        start: onset, end: onset.addingTimeInterval(hours * 3600), kind: .asleep, source: source,
        sourceID: id)
    ]
    if let inBed {
      samples.append(
        SleepSample(
          start: onset.addingTimeInterval(-TimeInterval(inBed * 60)), end: onset, kind: .inBed,
          source: source, sourceID: id))
    }
    return samples
  }

  func estimate(_ samples: [SleepSample]) -> SleepEstimate? {
    SleepEstimate(
      SleepNight.from(samples, calendar: london), now: now, calendar: london, config: config)
  }

  @Test func tunablesMatchTheBrief() {
    #expect(config.health.lookbackDays == 28)
    #expect(config.health.minNights == 7)
    #expect(config.health.weekendSplitMinutes == 45)
    #expect(config.suggestion.before == 60)
    #expect(config.suggestion.beforeMax == 90)
    #expect(config.suggestion.after == 30)
    #expect(config.gap.start == 15)
    #expect(config.after.start == 10)
  }

  @Test func sevenNightsAreTheLeast() {
    #expect(estimate((14...19).flatMap { night($0) }) == nil)
    let seven = estimate((14...20).flatMap { night($0) })
    #expect(seven?.nights == 7)
    #expect(seven?.usual == .init(asleep: time(23, 20), wake: time(7, 20)))
  }

  @Test func theMedianIsTakenAroundMidnight() throws {
    // 11:30 pm to 12:50 am: an average of the clock readings would land near noon.
    let samples = [90, 100, 110, 120, 130, 140, 150].enumerated().flatMap { index, minutes in
      night(16 + index, asleep: minutes)
    }
    let found = try #require(estimate(samples))
    #expect(found.usual.asleep == time(0, 0))
    #expect(found.usual.wake == time(8, 0))
    #expect(found.variability == 20)
  }

  @Test func onlyTheLastFourWeeksCount() {
    let stale = (1...10).flatMap { day in
      night(day, asleep: 20).map { sample in
        var moved = sample
        moved.start = sample.start.addingTimeInterval(-40 * 86_400)
        moved.end = sample.end.addingTimeInterval(-40 * 86_400)
        return moved
      }
    }
    #expect(estimate(stale) == nil)
  }

  @Test func weekendsAreApartOnlyWhenTheyDiffer() throws {
    // 14 to 27 November: Fri and Sat nights are the 20th, 21st (and the 14th, a Saturday).
    let weekend: Set<Int> = [14, 20, 21]
    let late = (14...24).flatMap { day in
      night(day, asleep: weekend.contains(day) ? 150 : 80, hours: weekend.contains(day) ? 9 : 8)
    }
    let apart = try #require(estimate(late))
    #expect(apart.usual == .init(asleep: time(23, 20), wake: time(7, 20)))
    #expect(apart.weekends == .init(asleep: time(0, 30), wake: time(9, 30)))
    #expect(apart.schedule.rules.count == 2)
    let close = (14...24).flatMap { day in night(day, asleep: weekend.contains(day) ? 110 : 80) }
    #expect(try #require(estimate(close)).weekends == nil)
  }

  @Test func aWatchWinsOverlappingSources() {
    let samples =
      (14...20).flatMap { night($0) }
      + (14...20).flatMap { night($0, asleep: 0, hours: 9, source: .phone, id: "phone") }
    let nights = SleepNight.from(samples, calendar: london)
    #expect(nights.count == 7)
    #expect(nights.allSatisfy { $0.source == .watch && $0.asleepMinutes == 480 })
    #expect(estimate(samples)?.usual.asleep == time(23, 20))
  }

  @Test func withoutAWatchTheSourceWithMostSleepCounts() {
    let samples =
      (14...20).flatMap { night($0, source: .other, id: "ring") }
      + night(14, asleep: 0, hours: 1, source: .phone, id: "phone")
    let nights = SleepNight.from(samples, calendar: london)
    #expect(nights.first?.source == .other)
  }

  @Test func overlapsInOneSourceCountOnce() {
    let start = date(2026, 11, 16, 23)
    let samples = [
      SleepSample(
        start: start, end: start.addingTimeInterval(3 * 3600), kind: .asleep, source: .watch,
        sourceID: "w"),
      SleepSample(
        start: start.addingTimeInterval(2 * 3600), end: start.addingTimeInterval(5 * 3600),
        kind: .asleep, source: .watch, sourceID: "w"),
    ]
    #expect(SleepNight.from(samples, calendar: london).first?.asleepMinutes == 300)
  }

  @Test func anAfternoonNapIsNotANight() {
    let nap = SleepSample(
      start: date(2026, 11, 16, 15), end: date(2026, 11, 16, 16), kind: .asleep, source: .watch,
      sourceID: "w")
    #expect(SleepNight.from([nap], calendar: london).isEmpty)
  }

  @Test func latencyNeedsTimeInBed() throws {
    let slow = try #require(estimate((14...20).flatMap { night($0, inBed: 40) }))
    #expect(slow.latency == 40)
    #expect(try #require(estimate((14...20).flatMap { night($0) })).latency == nil)
  }

  // MARK: Suggestion v0

  @Test func everyoneStartsFromTheBaseline() {
    let none = BufferSuggestion(nil)
    #expect((none.before, none.after, none.personal) == (60, 30, false))
    let steady = BufferSuggestion(estimate((14...20).flatMap { night($0, inBed: 10) }))
    #expect((steady.before, steady.after, steady.personal) == (60, 30, false))
  }

  @Test func slowOrScatteredSleepAddsAStepEach() {
    let slow = BufferSuggestion(estimate((14...20).flatMap { night($0, inBed: 45) }))
    #expect(slow.before == 75)
    #expect(slow.personal)
    let scattered = (14...20).enumerated().flatMap { index, day in
      night(day, asleep: index.isMultiple(of: 2) ? 0 : 200, inBed: 45)
    }
    let both = BufferSuggestion(estimate(scattered))
    #expect(both.before == 90)
    var tight = config
    tight.suggestion.beforeMax = 80
    #expect(BufferSuggestion(estimate(scattered), config: tight).before == 80)
  }

  @Test func aSuggestedFitStartsGently() {
    let fit = Fit.suggested(sleep: nil, BufferSuggestion(nil), health: false)
    #expect(fit.before == .init(start: 15, target: 60))
    #expect(fit.after == .init(start: 10, target: 30))
  }
}
