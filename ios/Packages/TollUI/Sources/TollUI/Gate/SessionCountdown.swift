import SwiftUI
import TollCore

/// The time left in a session (design §3.18): in the block bar's state line, or large on the block
/// card. Like `CountdownClock` it owns its tick, so a second passing redraws these digits and not
/// Home around them.
public struct SessionCountdown: View {
  public enum Style: Sendable {
    /// "Open · 6:42 left", the state line.
    case line
    /// "6:42" as a hero-style numeral.
    case numeral
  }

  let endsAt: Date
  let style: Style

  public init(endsAt: Date, style: Style = .line) {
    self.endsAt = endsAt
    self.style = style
  }

  public var body: some View {
    // Anchored a whole number of seconds before the end, so every tick lands on a digit change.
    let anchor = endsAt.addingTimeInterval(-WaitClock.anchorLead)
    TimelineView(.periodic(from: anchor, by: 1)) { context in
      SessionDigits(seconds: WaitClock.secondsLeft(until: endsAt, at: context.date), style: style)
    }
  }
}

private struct SessionDigits: View {
  let seconds: Int
  let style: SessionCountdown.Style

  var body: some View {
    Group {
      switch style {
      case .line:
        Text(Copy.ActiveBlock.open + Copy.middleDot + Copy.ActiveBlock.left(seconds: seconds))
          .tollText(.subhead)
          .monospacedDigit()
          .contentTransition(.numericText(countsDown: true))
          .animation(Motion.movement, value: seconds)
      case .numeral:
        HeroNumber(WaitClock.text(seconds), size: Self.numeralSize, countsDown: true)
      }
    }
    // Design §5: spoken in 30 s steps, so VoiceOver resting on it is not interrupted every second.
    // Unlike the wait card it posts no announcements: the bar sits on Home for the whole session.
    .accessibilityLabel(spoken)
    .accessibilityAddTraits(.updatesFrequently)
  }

  private var spoken: String {
    let left = WaitClock.spoken(step: WaitClock.spokenStep(seconds))
    switch style {
    case .line: return Copy.ActiveBlock.open + Copy.middleDot + left
    case .numeral: return left
    }
  }

  /// The size Friend detail and Insights use for a sheet's or a card's numeral (design §4.5).
  private static let numeralSize: CGFloat = 40
}
