import SwiftUI

/// A row's detail as facts, each led by its glyph (a house, then "Home"; a clock, then "9 am – 5 pm"), so the line
/// reads without its words (#78, #110). Facts wrap whole to the next line rather than squeeze; a
/// fact longer than the line wraps inside itself. The glyphs are marks (`label3`, design §2.3) and
/// stay in the wordless render; VoiceOver reads the words.
public struct FactLine: View {
  public struct Fact: Hashable, Sendable {
    let symbol: TollSymbol?
    let text: String

    public init(_ symbol: TollSymbol?, _ text: String) {
      self.symbol = symbol
      self.text = text
    }
  }

  let facts: [Fact]
  @ScaledMetric(relativeTo: .footnote) private var glyph: CGFloat = 11

  public init(_ facts: [Fact]) {
    self.facts = facts
  }

  public var body: some View {
    FlowLayout(spacing: 10, lineSpacing: 2) {
      ForEach(Array(facts.enumerated()), id: \.offset) { _, fact in
        HStack(alignment: .firstTextBaseline, spacing: 4) {
          if let symbol = fact.symbol {
            Image(symbol: symbol).unredacted()
              .font(.system(size: glyph, weight: .semibold))
              .foregroundStyle(TollColor.label3)
              .accessibilityHidden(true)
          }
          Text(fact.text)
            .tollType(.detail, TollColor.label2)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// Lays its views left to right and starts a new line when the next one doesn't fit.
struct FlowLayout: Layout {
  let spacing: CGFloat
  let lineSpacing: CGFloat

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let frames = place(subviews, width: proposal.width ?? .infinity)
    let width = frames.map(\.maxX).max() ?? 0
    let height = frames.map(\.maxY).max() ?? 0
    return CGSize(width: proposal.width.map { min($0, width) } ?? width, height: height)
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    let frames = place(subviews, width: bounds.width)
    for (subview, frame) in zip(subviews, frames) {
      subview.place(
        at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
        proposal: ProposedViewSize(frame.size))
    }
  }

  private func place(_ subviews: Subviews, width: CGFloat) -> [CGRect] {
    var frames: [CGRect] = []
    var x: CGFloat = 0
    var y: CGFloat = 0
    var lineHeight: CGFloat = 0
    for subview in subviews {
      let size = subview.sizeThatFits(ProposedViewSize(width: width, height: nil))
      let fitted = CGSize(width: min(size.width, width), height: size.height)
      if x > 0, x + fitted.width > width {
        x = 0
        y += lineHeight + lineSpacing
        lineHeight = 0
      }
      frames.append(CGRect(origin: CGPoint(x: x, y: y), size: fitted))
      x += fitted.width + spacing
      lineHeight = max(lineHeight, fitted.height)
    }
    return frames
  }
}
