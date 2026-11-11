import Accessibility
import SwiftUI
import TollCore

/// The countdown numeral (design §3.7). It owns its own tick, so one second passing redraws these
/// digits and nothing else: not the card, not the overlay, not Home under the blur. With no end
/// date it holds a still "0:00", which is what keeps the card's frame once the wait is over.
struct CountdownClock: View {
  let endsAt: Date?

  var body: some View {
    if let endsAt {
      // Anchored a whole number of seconds before the end, so every tick lands on a digit change.
      let anchor = endsAt.addingTimeInterval(-WaitClock.anchorLead)
      TimelineView(.periodic(from: anchor, by: 1)) { context in
        CountdownDigits(seconds: WaitClock.secondsLeft(until: endsAt, at: context.date))
      }
    } else {
      CountdownDigits(seconds: 0)
    }
  }
}

private struct CountdownDigits: View {
  let seconds: Int

  var body: some View {
    HeroNumber(WaitClock.text(seconds), countsDown: true)
      .accessibilityLabel(WaitClock.spoken(step: WaitClock.spokenStep(seconds)))
      .accessibilityAddTraits(.updatesFrequently)
      .onChange(of: WaitClock.spokenStep(seconds)) { _, step in
        // Design §5: VoiceOver hears the time every 30 s without having to focus the numeral.
        // Zero is not announced; the session picker takes over there.
        guard step > 0 else { return }
        AccessibilityNotification.Announcement(WaitClock.spoken(step: step)).post()
      }
  }
}

enum WaitClock {
  /// Longer than any wait, so the timeline's anchor is always in the past.
  static let anchorLead: TimeInterval = 86_400

  /// Rounded up so the card never shows less than is left. Ticks arrive a hair either side of the
  /// whole second; the margin keeps an early one from repeating the second before.
  static func secondsLeft(until end: Date, at date: Date) -> Int {
    max(0, Int((end.timeIntervalSince(date) - 0.05).rounded(.up)))
  }

  static func text(_ seconds: Int) -> String {
    let total = max(0, seconds)
    return String(format: "%d:%02d", total / 60, total % 60)
  }

  /// The time in 30 s steps, rounded up so it never sounds shorter than it is.
  static func spokenStep(_ seconds: Int) -> Int {
    (max(0, seconds) + 29) / 30 * 30
  }

  static func spoken(step: Int) -> String {
    Copy.Wait.remainingAccessibility(minutes: step / 60, seconds: step % 60)
  }
}
