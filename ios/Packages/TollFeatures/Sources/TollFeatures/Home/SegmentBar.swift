import SwiftUI
import TollCore
import TollUI

/// One segment of Tonight's strip: solid while on, outlined before, faint once over, dashed when
/// nothing will block. The night in amber; other blocks in greys. The kind's glyph when there's room
/// for it. The night's gap before bed (D76) is a lower step before the tall bar with the moon, split
/// from it by a notch, so it reads as part of the night and apart from it by shape, not colour.
struct SegmentBar: View {
  let segment: DayTimeline.Segment
  let width: CGFloat

  static let gapHeight: CGFloat = 14
  static let notch: CGFloat = 2
  /// 15 minutes is under 4 pt of a day: the step is drawn at least this wide so it can be seen.
  static let gapMinWidth: CGFloat = 8

  var body: some View {
    if let share = gapShare {
      HStack(spacing: Self.notch) {
        bar(glyph: false)
          .frame(
            width: max(Self.gapMinWidth, width * share - Self.notch / 2), height: Self.gapHeight)
        bar(glyph: true)
      }
    } else {
      bar(glyph: true)
    }
  }

  /// The gap's share of the night's bar; nil without one, or with no room to draw it.
  private var gapShare: Double? {
    guard segment.isNight, let bed = segment.bed, segment.end > segment.start else { return nil }
    let share = (bed - segment.start) / (segment.end - segment.start)
    return share > 0 && share < 1 && width * (1 - share) >= 2 * Self.gapMinWidth ? share : nil
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
