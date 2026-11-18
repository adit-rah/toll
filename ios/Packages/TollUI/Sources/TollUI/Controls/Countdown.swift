import SwiftUI

/// A line that counts down to `endsAt` each second ("Opens in 1:29."). VoiceOver hears it in 30 s
/// steps and is told every 30 s, never every second (design §4).
public struct Countdown: View {
  let endsAt: Date
  let text: (String) -> String
  let spoken: (_ minutes: Int, _ seconds: Int) -> String

  public init(
    endsAt: Date, text: @escaping (String) -> String,
    spoken: @escaping (_ minutes: Int, _ seconds: Int) -> String
  ) {
    self.endsAt = endsAt
    self.text = text
    self.spoken = spoken
  }

  public var body: some View {
    // Anchored a whole number of seconds before the end, so every tick lands on a digit change.
    TimelineView(.periodic(from: endsAt.addingTimeInterval(-86_400), by: 1)) { context in
      let seconds = Self.secondsLeft(until: endsAt, at: context.date)
      Text(text(Self.clock(seconds)))
        .monospacedDigit()
        .contentTransition(.numericText(countsDown: true))
        .animation(Motion.movement, value: seconds)
        .accessibilityLabel(spoken(Self.step(seconds) / 60, Self.step(seconds) % 60))
        .accessibilityAddTraits(.updatesFrequently)
        .onChange(of: Self.step(seconds)) { _, step in
          guard step > 0 else { return }
          AccessibilityNotification.Announcement(spoken(step / 60, step % 60)).post()
        }
    }
  }

  /// Rounded up so it never shows less than is left; the margin keeps an early tick from repeating.
  static func secondsLeft(until end: Date, at date: Date) -> Int {
    max(0, Int((end.timeIntervalSince(date) - 0.05).rounded(.up)))
  }

  static func clock(_ seconds: Int) -> String {
    String(format: "%d:%02d", seconds / 60, seconds % 60)
  }

  static func step(_ seconds: Int) -> Int { (max(0, seconds) + 29) / 30 * 30 }
}
