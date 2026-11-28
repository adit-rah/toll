import Foundation
import Testing

@testable import TollCore

/// The sleep model's insight on screen (#189, #182): Your sleep states it, sooner or later, with
/// its range and nights, or says Dusk is still learning; Tonight's settled week points to it; and
/// only its sentence says "because".
struct TimingInsightTests {
  static let sooner = ModelReading.Insight(minutes: 12.4, low: 5.2, high: 19.1, nights: 34)
  static let later = ModelReading.Insight(minutes: -8.4, low: -14.2, high: -2.6, nights: 41)

  static func settled(_ offset: Int) -> Timing.Hold {
    Timing.Hold(start: "2026-11-23", offset: offset, prob: 0.93, settled: true)
  }

  func sleep(_ state: DuskState, _ model: ModelReading?) -> YourSleep {
    YourSleep(
      state: state, log: [], history: [], now: date(2026, 11, 23, 15), calendar: london,
      model: model)
  }

  // MARK: Tonight

  @Test func aSettledWeekPointsToWhatWasFound() throws {
    let state = TimingTests.held(Self.settled(-30))
    let model = ModelReading(nights: 34, insight: Self.sooner)
    let home = HomeSnapshot(
      state: state, log: [], now: date(2026, 11, 23, 15), calendar: london, model: model)
    let held = try #require(home.heldStart)
    #expect(held.found)
    #expect(held.text == "30 min earlier this week, from what Dusk found")
    #expect(
      held.spoken == "30 minutes earlier this week, from what Dusk found. It's on Your sleep.")
  }

  @Test func laterAsleepSettlesLater() {
    let state = TimingTests.held(Self.settled(30))
    let held = HeldStart(state, insight: Self.later)
    #expect(held?.text == "30 min later this week, from what Dusk found")
  }

  /// A week drawn to learn says so, even once an insight shows mid-week (D66 settles only at a
  /// week's start).
  @Test func aWeekDrawnToLearnSaysSo() {
    let state = TimingTests.held(TimingTests.earlier)
    let held = HeldStart(state, insight: Self.sooner)
    #expect(held?.found == false)
    #expect(held?.text == "30 min earlier this week, to learn what helps")
  }

  /// The insight stopped holding (`PersonState.shown` fell away): the week keeps its start until
  /// Sunday, and the line goes back to learning, saying nothing of what left.
  @Test func anInsightThatStopsHoldingLeavesQuietly() {
    let state = TimingTests.held(Self.settled(-30))
    #expect(HeldStart(state, insight: nil)?.text == "30 min earlier this week, to learn what helps")
    #expect(sleep(state, ModelReading(nights: 52)).finding == nil)
  }

  /// A settled person's week of exploring (D99, 7%) on the other side is a week to learn.
  @Test func exploringTheOtherSideIsLearning() {
    let state = TimingTests.held(Self.settled(30))
    #expect(HeldStart(state, insight: Self.sooner)?.found == false)
  }

  /// One line at the default size, so the time above it doesn't move (D105, `theReasonIsShort`).
  @Test func theFoundReasonIsShort() {
    for offset in TollConfig.defaults.timing.offsets where offset != 0 {
      #expect(Copy.Timing.heldFound(offset).count <= 46)
    }
  }

  // MARK: Your sleep

  @Test func soonerAsleep() throws {
    let finding = try #require(
      sleep(TimingTests.held(Self.settled(-30)), ModelReading(nights: 34, insight: Self.sooner))
        .finding)
    #expect(finding.sooner)
    #expect(finding.value == "Asleep 12 min sooner")
    #expect(finding.line == "You fell asleep sooner because apps locked 30 min earlier.")
    #expect(finding.detail == "Likely 5 to 19 min, from 34 nights")
    #expect(
      finding.spoken
        == "Asleep 12 minutes sooner. You fell asleep sooner because apps locked 30 minutes earlier. Likely 5 to 19 minutes, from 34 nights."
    )
  }

  /// Later is said as plainly as sooner, with the range's smaller end first.
  @Test func laterAsleep() throws {
    let sleep = sleep(
      TimingTests.held(Self.settled(30)), ModelReading(nights: 41, insight: Self.later))
    let finding = try #require(sleep.finding)
    #expect(!finding.sooner)
    #expect(finding.value == "Asleep 8 min later")
    #expect(finding.line == "You fell asleep later because apps locked 30 min earlier.")
    #expect(finding.detail == "Likely 3 to 14 min, from 41 nights")
    #expect(sleep.learning == nil)
  }

  /// The range never reaches zero (the zero test is stricter), so it never reads "0".
  @Test func theRangeNeverReadsZero() throws {
    let close = ModelReading.Insight(minutes: 6, low: 0.3, high: 11.7, nights: 60)
    let finding = try #require(
      sleep(TimingTests.timed(), ModelReading(nights: 60, insight: close)).finding)
    #expect(finding.detail == "Likely 1 to 12 min, from 60 nights")
  }

  @Test func withTimingOnAndNothingFoundItSaysItIsLearning() {
    let sleep = sleep(TimingTests.held(), ModelReading(nights: 12))
    #expect(sleep.finding == nil)
    #expect(
      sleep.learning
        == "Dusk is still learning what helps your sleep, from 12 nights so far. Anything it finds shows here."
    )
    // Before the model has been read, or with no usable night yet: no count.
    #expect(
      self.sleep(TimingTests.timed(), nil).learning
        == "Dusk is still learning what helps your sleep. Anything it finds shows here.")
    #expect(
      self.sleep(TimingTests.timed(), ModelReading(nights: 1)).learning?.contains("from 1 night so")
        == true)
  }

  /// Someone who never chose timing hears nothing about learning; an insight from weeks when it
  /// was on is still a fact about their nights.
  @Test func withTimingOffOnlyAnInsightShows() {
    var state = TimingTests.timed()
    state.timing.on = false
    #expect(sleep(state, ModelReading(nights: 30)).learning == nil)
    #expect(sleep(state, ModelReading(nights: 30)).finding == nil)
    #expect(sleep(state, ModelReading(nights: 34, insight: Self.sooner)).finding != nil)
  }

  /// Only the insight's sentence may say "because": only the start was randomized (#189).
  @Test func onlyTheInsightSaysBecause() throws {
    let because = try CopyTermsTests.copyLiterals().filter {
      $0.1.lowercased().contains("because")
    }
    #expect(!because.isEmpty)
    for (file, literal) in because {
      #expect(file == "Copy+Timing.swift" && literal.contains("because apps locked"), "\(literal)")
    }
  }
}
