#if DEBUG
  import Foundation
  import TollCore

  /// Personal timing's scenarios (#171): the offer's card on the evening after the first week, its
  /// sheet, Tonight with this week's start held 30 minutes earlier, and Settings › Sleep's switch
  /// off and on.
  extension DemoScenario {
    /// The one-time flow's card or sheet is what the screen shows.
    var timingOffered: Bool { [.homeTimingCard, .timingSheet].contains(self) }
    /// This week's start is 30 minutes earlier than the person's own.
    var timingHeld: Bool { [.homeTimingHeld, .settingsSleepTimingOn].contains(self) }
    /// Health chosen and the first week behind them, as the offer needs.
    var timingWeek: Bool { timingOffered || timingHeld || self == .settingsSleepTimingOff }
  }

  extension DemoFixture {
    mutating func timing(_ scenario: DemoScenario, now: Date) {
      guard scenario.timingWeek else { return }
      let calendar = Calendar.current
      state.health = true
      state.setupFinishedAt = calendar.date(byAdding: .day, value: -9, to: now)
      state.trial.start = state.setupFinishedAt
      guard scenario.timingHeld else { return }
      state.timing.on = true
      let weekday = calendar.component(.weekday, from: now)
      let monday = calendar.date(byAdding: .day, value: -((weekday + 5) % 7), to: now) ?? now
      let parts = calendar.dateComponents([.year, .month, .day], from: monday)
      let start = String(
        format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
      // In force from before any night the demo shows, as a state brought back from a record is.
      state.timing.history = [
        Timing.Entry(
          night: Date(timeIntervalSince1970: 0),
          hold: Timing.Hold(start: start, offset: -30, prob: 0.4, settled: false))
      ]
    }
  }
#endif
