import SwiftUI
import TollCore

/// A state's glyph before its eyebrow, in the same place on every screen that has a state (#72,
/// rule 2): blocked, later, away, off. The glyph is hidden from VoiceOver; the words say it.
public struct StateLine: View {
  let symbol: TollSymbol
  let text: String
  let tone: Tone
  let prominent: Bool

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

  /// `prominent` draws the glyph at 19 pt (Tonight's state, #74), big enough to tell the states
  /// apart with every word wiped, without making the line any taller: the big time under it keeps
  /// its place (D86, D87).
  public init(_ text: String, symbol: TollSymbol, tone: Tone = .neutral, prominent: Bool = false) {
    self.text = text
    self.symbol = symbol
    self.tone = tone
    self.prominent = prominent
  }

  public var body: some View {
    HStack(spacing: prominent ? 8 : 6) {
      Image(symbol: symbol).unredacted()
        .tollGlyph(prominent ? 19 : 13, weight: .semibold, relativeTo: .caption)
        .foregroundStyle(tone.color)
        // Centred on the line and drawn past it, so the line keeps the eyebrow's height.
        .frame(height: prominent ? 0 : nil)
        .accessibilityHidden(true)
      Text(text).tollType(.eyebrow, TollColor.label2)
    }
  }
}

/// A state as a shape on its own, centred over its eyebrow (#74): Ready's tick, and Tonight's
/// state when nothing will block, where there's no time and the mark is drawn at 64 pt to stand in
/// for it (design §2.6). No tile behind it: a filled square reads as a button. Hidden from
/// VoiceOver; the eyebrow and the time say it.
public struct StateMark: View {
  let symbol: TollSymbol
  let tone: StateLine.Tone
  let large: Bool
  let spoken: String?
  /// Grows with the words around it (#124), to twice its size (half again when large): past that
  /// it would crowd the time.
  @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

  /// `spoken` names the mark to VoiceOver when nothing else on screen says the state.
  public init(
    _ symbol: TollSymbol, tone: StateLine.Tone = .neutral, large: Bool = false,
    spoken: String? = nil
  ) {
    self.symbol = symbol
    self.tone = tone
    self.large = large
    self.spoken = spoken
  }

  public var body: some View {
    // The 64 pt mark is already the biggest shape on screen; it grows less.
    let grow = min(scale, large ? 1.5 : 2)
    Image(symbol: symbol).unredacted()
      .font(.system(size: (large ? 44 : 26) * grow, weight: large ? .light : .regular))
      .foregroundStyle(tone.color)
      .frame(width: (large ? 64 : 40) * grow, height: (large ? 64 : 36) * grow)
      .accessibilityHidden(spoken == nil)
      .accessibilityLabel(spoken ?? "")
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
        .tollGlyph(12, weight: .semibold)
        .accessibilityHidden(true)
      Text(text)
    }
    .tollType(.trailing, tone == .neutral ? TollColor.label2 : tone.color)
  }
}

/// A count as dots (#72, rule 4): filled for each left, outlined for each used, with the count in
/// words for VoiceOver. Unlocks, the free nights, the refill's nights.
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
  let perRow: Int?
  let current: Int?

  /// `perRow` wraps the marks into rows, a week to a row for the free nights (D78). `current` rings
  /// the mark at that index in the accent: tonight's night, so "Night 5" shows four filled and one
  /// ringed rather than four that read as five.
  public init(
    filled: Int, total: Int, style: Style = .dots, spoken: String, perRow: Int? = nil,
    current: Int? = nil
  ) {
    self.filled = filled
    self.total = total
    self.style = style
    self.spoken = spoken
    self.perRow = perRow
    self.current = current
  }

  public var body: some View {
    let count = max(total, 0)
    let row = max(perRow ?? count, 1)
    VStack(alignment: .leading, spacing: style == .dots ? 6 : 3) {
      ForEach(Array(stride(from: 0, to: count, by: row)), id: \.self) { first in
        HStack(spacing: style == .dots ? 6 : 3) {
          ForEach(first..<min(first + row, count), id: \.self) { mark($0) }
        }
      }
    }
    .animation(Motion.stateChange, value: filled)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(spoken)
  }

  /// Filled, empty, or ringed for `current`: an outline, so it differs by shape and not by colour.
  @ViewBuilder private func mark(_ index: Int) -> some View {
    let on = index < filled
    let ringed = !on && index == current
    switch style {
    case .dots:
      Circle()
        .fill(on ? TollColor.accent : Color.clear)
        .overlay(
          Circle().strokeBorder(
            on ? Color.clear : ringed ? TollColor.accent : TollColor.label3, lineWidth: 1.5)
        )
        .frame(width: 12, height: 12)
    case .segments:
      RoundedRectangle(cornerRadius: 2, style: .continuous)
        .fill(on ? TollColor.accent : ringed ? Color.clear : TollColor.bar)
        .overlay {
          if ringed {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
              .strokeBorder(TollColor.accent, lineWidth: 1.5)
          }
        }
        .frame(width: 10, height: 6)
    }
  }
}
