import SwiftUI
import TollCore
import TollUI

/// Tonight's strip of the whole day (D75), at the bottom like a horizon (D64): from the night's end
/// to the same time tomorrow on an 8 pt track. The night is the tall amber bar with its moon; every
/// other block is a shorter grey bar with its kind's glyph, so the two differ by height and symbol
/// as well as colour. A 2 pt line marks now. Each segment is a button at least 44 pt wide; a tap
/// opens its snippet in a popover, Apple's own presentation (design §2.5).
struct DayStrip: View {
  let timeline: DayTimeline
  let openBlock: (BlockID) -> Void
  /// Demo renders open on this block's snippet (docs/renders.md).
  var initial: BlockID?
  @State private var selected: Int?
  @Environment(\.dynamicTypeSize) private var typeSize

  static let nightHeight: CGFloat = 24
  static let dayHeight: CGFloat = 14

  var body: some View {
    VStack(spacing: 10) {
      GeometryReader { proxy in
        let width = proxy.size.width
        let targets = timeline.targets(
          minimum: width > 0 ? TollSpacing.minTapTarget / width : 1)
        ZStack(alignment: .topLeading) {
          RoundedRectangle(cornerRadius: 4).fill(TollColor.surfaceRaised)
            .frame(width: width, height: 8)
            .offset(y: (Self.nightHeight - 8) / 2)
            .accessibilityHidden(true)
          // The night last, so it sits over any block whose hours run into it.
          ForEach(timeline.segments.filter { !$0.isNight } + timeline.segments.filter(\.isNight)) {
            segment in
            let barWidth = max(6, width * (segment.end - segment.start))
            let height = segment.isNight ? Self.nightHeight : Self.dayHeight
            SegmentBar(segment: segment, width: barWidth)
              .frame(width: barWidth, height: height)
              .offset(x: width * segment.start, y: (Self.nightHeight - height) / 2)
              .accessibilityHidden(true)
          }
          now(width)
          ForEach(targets.indices, id: \.self) { index in
            target(targets[index], index: index, width: width)
          }
        }
        .task {
          guard let initial, selected == nil else { return }
          // After the first frame: a popover asked for before the screen is up doesn't show.
          try? await Task.sleep(for: .milliseconds(800))
          selected = targets.firstIndex {
            $0.segments.contains { timeline.segments[$0].block == initial }
          }
        }
      }
      .frame(height: Self.nightHeight)
      .padding(.top, 26)
      HourMarks(hours: timeline.hours)
    }
    .tollChartTypeLimit()
    .accessibilityElement(children: .contain)
  }

  private func now(_ width: CGFloat) -> some View {
    ZStack(alignment: .topLeading) {
      RoundedRectangle(cornerRadius: 1)
        .fill(TollColor.label)
        .frame(width: 2, height: Self.nightHeight + 12)
        .offset(x: width * timeline.now - 1, y: -6)
      Text(Copy.Home.now)
        .tollType(TollType(size: 11, lineHeight: 14, weight: .semibold, style: .caption2))
        .foregroundStyle(TollColor.label)
        .fixedSize()
        // Positioned, not offset by an alignment guide: a guide widens the stack and shifts the
        // track off the hour labels.
        .position(x: min(max(width * timeline.now, 14), width - 14), y: -17)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(timeline.nowLabel)
  }

  private func target(_ target: DayTimeline.Target, index: Int, width: CGFloat) -> some View {
    let segments = target.segments.map { timeline.segments[$0] }
    return Button {
      selected = index
    } label: {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(Color.clear)
        .frame(width: width * (target.end - target.start), height: TollSpacing.minTapTarget)
        .contentShape(Rectangle())
    }
    .buttonStyle(StripTargetStyle())
    .accessibilityLabel(segments.map(\.spoken).joined(separator: "; "))
    .accessibilityHint(Copy.Strip.hint)
    .accessibilityIdentifier("strip.\(segments.first?.block.raw ?? "")")
    .accessibilityActions {
      ForEach(segments) { segment in
        Button(Copy.Strip.edit(segment.title)) { openBlock(segment.block) }
      }
    }
    .popover(
      isPresented: Binding(
        get: { selected == index }, set: { if !$0, selected == index { selected = nil } })
    ) {
      StripSnippet(segments: segments) { block in
        selected = nil
        openBlock(block)
      }
      .presentationCompactAdaptation(typeSize.isAccessibilitySize ? .sheet : .popover)
      .presentationDetents([.medium, .large])
      .presentationBackground(TollColor.surface)
    }
    .offset(x: width * target.start, y: (Self.nightHeight - TollSpacing.minTapTarget) / 2)
  }
}

/// Shows where a tap landed: the hit area tints while pressed, with no motion.
private struct StripTargetStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.background(
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(configuration.isPressed ? TollColor.separator : Color.clear))
  }
}

/// One segment: solid while on, outlined before, faint once over, dashed when nothing will block.
/// The night in amber; other blocks in greys. The kind's glyph when there's room for it.
private struct SegmentBar: View {
  let segment: DayTimeline.Segment
  let width: CGFloat

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: segment.isNight ? 6 : 4, style: .continuous)
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
            shape.strokeBorder(TollColor.label3, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
      }
      if width >= 22 {
        Image(symbol: .block(segment.kind)).unredacted()
          .font(.system(size: segment.isNight ? 11 : 9, weight: .semibold))
          .foregroundStyle(glyph)
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

/// Every six hours on the clock, each label centred on its hour.
private struct HourMarks: View {
  let hours: [DayTimeline.Hour]

  var body: some View {
    GeometryReader { proxy in
      ZStack(alignment: .topLeading) {
        ForEach(hours.indices, id: \.self) { index in
          Text(hours[index].label).fixedSize()
            .position(x: proxy.size.width * hours[index].at, y: 7)
        }
      }
    }
    .frame(height: 14)
    .tollType(.micro, TollColor.label2)
    .accessibilityHidden(true)
  }
}
