#if DEBUG
  import Foundation
  import TollCore

  /// The sleep model's insight on screen (#189, #182): Your sleep after weeks of personal timing,
  /// asleep sooner with an earlier start, asleep later with it, and still learning; and Tonight in
  /// a week settled on what was found. The model's numbers are given, as the app's `ModelStore`
  /// would hand them over; the nights under them are the sleep stories' (`DemoSleep`).
  extension DemoScenario {
    /// A week whose start settled on the insight (D66).
    var settledWeek: Bool {
      [.homeTimingSettled, .sleepInsightSooner, .sleepInsightLater].contains(self)
    }

    /// What the model says in this scenario; nil where it doesn't matter.
    var sleepModel: ModelReading? {
      switch self {
      case .homeTimingSettled, .sleepInsightSooner:
        ModelReading(
          nights: 34,
          insight: ModelReading.Insight(minutes: 12.4, low: 5.2, high: 19.1, nights: 34))
      case .sleepInsightLater:
        ModelReading(
          nights: 41,
          insight: ModelReading.Insight(minutes: -8.4, low: -14.2, high: -2.6, nights: 41))
      case .sleepLearning: ModelReading(nights: 18)
      default: nil
      }
    }

    /// Nights behind Your sleep's insight scenarios, every one of them usable.
    var insightNights: Int? {
      switch self {
      case .sleepInsightSooner: 34
      case .sleepInsightLater: 41
      case .sleepLearning: 18
      default: nil
      }
    }
  }

  extension DemoFixture {
    /// Timing on for Your sleep's insight scenarios: this week settled earlier for sooner and later
    /// for later; a week drawn to learn while still learning.
    mutating func insight(_ scenario: DemoScenario, now: Date) {
      switch scenario {
      case .sleepInsightSooner: hold(offset: -30, settled: true, now: now)
      case .sleepInsightLater: hold(offset: 30, settled: true, now: now)
      case .sleepLearning: hold(offset: 30, settled: false, now: now)
      default: break
      }
    }
  }
#endif
