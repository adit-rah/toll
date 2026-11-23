import SwiftUI

/// How full a limit is, as a bar (#78): the 40 apps and sites across every block. Over it, the fill
/// turns `warn` and the bar is full, so the shape says it before the colour does (design §4).
/// VoiceOver reads the count beside it instead.
public struct CapacityBar: View {
  let used: Int
  let max: Int

  public init(used: Int, of max: Int) {
    self.used = used
    self.max = max
  }

  public var body: some View {
    let fraction = max > 0 ? min(1, Double(used) / Double(max)) : 0
    let over = used > max
    GeometryReader { proxy in
      ZStack(alignment: .leading) {
        Capsule().fill(TollColor.bar)
        Capsule()
          .fill(over ? TollColor.warn : TollColor.accent)
          .frame(width: proxy.size.width * fraction)
      }
    }
    .frame(height: 6)
    .accessibilityHidden(true)
  }
}

/// A slot still to fill (#78): the tile of a row Save is waiting for, as a dashed outline, the same
/// dashed language as an empty night.
public struct EmptyTile: View {
  let symbol: TollSymbol
  @ScaledMetric(relativeTo: .callout) private var scale: CGFloat = 1

  public init(_ symbol: TollSymbol) {
    self.symbol = symbol
  }

  public var body: some View {
    let grow = min(scale, 1.5)
    let size = TileSize.row
    Image(symbol: symbol).unredacted()
      .font(.system(size: size.symbol * grow, weight: .medium))
      .foregroundStyle(TollColor.label3)
      .frame(width: size.side * grow, height: size.side * grow)
      .overlay(
        RoundedRectangle(cornerRadius: size.radius * grow, style: .continuous)
          .strokeBorder(TollColor.label3, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
      )
      .accessibilityHidden(true)
  }
}
