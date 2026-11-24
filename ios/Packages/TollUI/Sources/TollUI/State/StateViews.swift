import SwiftUI
import TollCore

/// A state's glyph before its eyebrow, in the same place on every screen that has a state (#72,
/// rule 2): blocked, later, away, off. The glyph is hidden from VoiceOver; the words say it.
public struct StateLine: View {
  let symbol: TollSymbol
  let text: String
  let tone: Tone

  public enum Tone: Sendable {
    case accent, neutral, warn

    var color: Color {
      switch self {
      case .accent: TollColor.accent
      case .neutral: TollColor.label2
      case .warn: TollColor.warn
      }
    }
  }

  public init(_ text: String, symbol: TollSymbol, tone: Tone = .neutral) {
    self.text = text
    self.symbol = symbol
    self.tone = tone
  }

  public var body: some View {
    HStack(spacing: 6) {
      Image(symbol: symbol).unredacted()
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(tone.color)
        .accessibilityHidden(true)
      Text(text).tollType(.eyebrow, TollColor.label2)
    }
  }
}

/// A status value: a glyph and a word, never the colour alone (#72, C4): "✓ Always", "⚠ Off",
/// "🔒 On now".
public struct StatusValue: View {
  let text: String
  let symbol: TollSymbol
  let tone: StateLine.Tone

  public init(_ text: String, symbol: TollSymbol, tone: StateLine.Tone = .neutral) {
    self.text = text
    self.symbol = symbol
    self.tone = tone
  }

  public var body: some View {
    HStack(spacing: 4) {
      Image(symbol: symbol).unredacted()
        .font(.system(size: 12, weight: .semibold))
        .accessibilityHidden(true)
      Text(text)
    }
    .tollType(.trailing, tone == .neutral ? TollColor.label2 : tone.color)
  }
}

/// A count as dots (#72, rule 4): filled for each left, outlined for each used, with the count in
/// words for VoiceOver. Unlocks, the free week's nights, the refill's nights.
public struct Pips: View {
  public enum Style: Sendable {
    /// 12 pt dots: unlocks.
    case dots
    /// Short bars: nights.
    case segments
  }

  let filled: Int
  let total: Int
  let style: Style
  let spoken: String

  public init(filled: Int, total: Int, style: Style = .dots, spoken: String) {
    self.filled = filled
    self.total = total
    self.style = style
    self.spoken = spoken
  }

  public var body: some View {
    HStack(spacing: style == .dots ? 6 : 3) {
      ForEach(0..<max(total, 0), id: \.self) { index in
        let on = index < filled
        switch style {
        case .dots:
          Circle()
            .fill(on ? TollColor.accent : Color.clear)
            .overlay(Circle().strokeBorder(on ? Color.clear : TollColor.label3, lineWidth: 1.5))
            .frame(width: 12, height: 12)
        case .segments:
          RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(on ? TollColor.accent : TollColor.bar)
            .frame(width: 10, height: 6)
        }
      }
    }
    .animation(Motion.stateChange, value: filled)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(spoken)
  }
}
