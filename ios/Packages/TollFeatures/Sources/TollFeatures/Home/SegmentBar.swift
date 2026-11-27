import SwiftUI
import TollCore
import TollUI

/// One segment of Tonight's strip: solid while on, outlined before, faint once over, dashed when
/// nothing will block. The night in amber; other blocks in greys. The kind's glyph when there's room
/// for it. The night's buffers (D76, #144) sit either side of sleep's bar with the moon, the same
/// height, at true scale and striped, each split from it by a notch, so before · sleep · after
/// read apart by texture and place, not colour.
struct SegmentBar: View {
  let segment: DayTimeline.Segment
  let width: CGFloat

  static let notch: CGFloat = 2
  /// At true scale 15 minutes is under 4 pt of a day: never thinner than this, so it's there.
  static let gapMinWidth: CGFloat = 4

  var body: some View {
    let (before, after) = shares
    if before != nil || after != nil {
      HStack(spacing: Self.notch) {
        if let before { step(before) }
        bar(glyph: true)
        if let after { step(after) }
      }
    } else {
      bar(glyph: true)
    }
  }

  private func step(_ share: Double) -> some View {
    buffer
      .frame(width: max(Self.gapMinWidth, width * share - Self.notch / 2))
  }

  /// A buffer: the night's own fill for its phase, striped.
  @ViewBuilder private var buffer: some View {
    switch segment.phase {
    case .on: HatchedBar(fill: TollColor.accent, stripes: TollColor.bg, radius: 4)
    case .later: HatchedBar(fill: TollColor.accentSoft, stripes: TollColor.accent, radius: 4)
    case .ended: HatchedBar(fill: TollColor.accentSoft, stripes: TollColor.bg, radius: 4)
    case .off:
      RoundedRectangle(cornerRadius: 4, style: .continuous)
        .strokeBorder(TollColor.label3, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
    }
  }

  /// Each buffer's share of the night's bar; nil without one, or with no room to draw it.
  private var shares: (before: Double?, after: Double?) {
    guard segment.isNight, segment.end > segment.start else { return (nil, nil) }
    let length = segment.end - segment.start
    let before = segment.bed.map { ($0 - segment.start) / length }.flatMap { $0 > 0 ? $0 : nil }
    let after = segment.wake.map { (segment.end - $0) / length }.flatMap { $0 > 0 ? $0 : nil }
    let sleep = 1 - (before ?? 0) - (after ?? 0)
    guard width * sleep >= 2 * Self.gapMinWidth else { return (nil, nil) }
    return (before, after)
  }

  private func bar(glyph showsGlyph: Bool) -> some View {
    let shape = RoundedRectangle(cornerRadius: segment.isNight ? 6 : 4, style: .continuous)
    return GeometryReader { proxy in
      ZStack {
        switch segment.phase {
        case .on: shape.fill(segment.isNight ? TollColor.accent : TollColor.label2)
        case .later:
          shape.fill(segment.isNight ? TollColor.accentSoft : TollColor.bg)
            .overlay(
              shape.strokeBorder(
                segment.isNight ? TollColor.accent : TollColor.label3, lineWidth: 1.5))
        case .ended: shape.fill(segment.isNight ? TollColor.accentSoft : TollColor.bar)
        case .off:
          shape.fill(TollColor.bg)
            .overlay(
              shape.strokeBorder(
                TollColor.label3, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
        }
        if showsGlyph, proxy.size.width >= 22 {
          Image(symbol: .block(segment.kind)).unredacted()
            .font(.system(size: segment.isNight ? 11 : 9, weight: .semibold))
            .foregroundStyle(glyph)
        }
      }
    }
  }

  private var glyph: Color {
    switch segment.phase {
    case .on: segment.isNight ? TollColor.onAccent : TollColor.bg
    case .later: segment.isNight ? TollColor.accent : TollColor.label2
    case .ended: segment.isNight ? TollColor.accent : TollColor.label3
    case .off: TollColor.label3
    }
  }
}
