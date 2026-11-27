import SwiftUI
import TollCore
import TollUI

/// What a tap on the strip shows (D75): for each block under the tap, its kind's tile and name
/// ("Your night" for the night), its state as a glyph and a word, its hours, its apps and where it
/// runs, and a link into its editor; at the strip's start, last night's card. Two blocks too close
/// to tap apart share one snippet.
struct StripSnippet: View {
  let segments: [DayTimeline.Segment]
  let edit: (BlockID) -> Void

  /// The popover takes the content's own height; at accessibility sizes, as a sheet, it scrolls.
  var body: some View {
    ViewThatFits(in: .vertical) {
      content
      ScrollView { content }
    }
    .frame(minWidth: 260, idealWidth: 290, maxWidth: 340)
    .background(TollColor.surface)
  }

  private var content: some View {
    VStack(alignment: .leading, spacing: 0) {
      ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
        if index > 0 { Hairline().padding(.vertical, 12) }
        // Last night's card, the same one the morning shows, so it can be read again all day.
        if let night = segment.lastNight {
          LastNightCard(night: night).padding(.bottom, 10)
        } else {
          section(segment)
        }
      }
    }
    .padding(.top, 16)
    .padding(.bottom, 6)
    .padding(.horizontal, TollSpacing.cardPadding)
    .frame(maxWidth: .infinity, alignment: .leading)
    .fixedSize(horizontal: false, vertical: true)
  }

  private func section(_ segment: DayTimeline.Segment) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: TollSpacing.rowGap) {
        IconTile(.block(segment.kind), accent: segment.isNight)
        VStack(alignment: .leading, spacing: 1) {
          Text(segment.title).tollType(.rowTitle, TollColor.label)
          StatusValue(
            segment.stateText, symbol: stateSymbol(segment.state),
            tone: segment.state == .on ? .accent : .neutral)
        }
      }
      .accessibilityElement(children: .combine)
      .accessibilityAddTraits(.isHeader)
      .padding(.bottom, 4)
      fact(.hours, segment.hours)
      // The hours start at the lock; bed is the moon (D76).
      if let bed = segment.bedText { fact(.sleep, bed) }
      fact(.apps, segment.apps)
      fact(placeSymbol(segment.placeKind), segment.place)
      Button {
        edit(segment.block)
      } label: {
        HStack(spacing: 4) {
          Text(Copy.Strip.edit)
          Image(symbol: .forward).unredacted()
            .tollGlyph(12, weight: .bold)
            .accessibilityHidden(true)
        }
        .frame(minHeight: TollSpacing.minTapTarget)
        .contentShape(Rectangle())
      }
      .buttonStyle(.tollPressable)
      .tollType(.action, TollColor.accent)
      .accessibilityLabel(Copy.Strip.edit(segment.title))
    }
  }

  private func fact(_ symbol: TollSymbol, _ text: String) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      Image(symbol: symbol).unredacted()
        .tollGlyph(13, weight: .medium)
        .foregroundStyle(TollColor.label2)
        .frame(minWidth: 18)
        .accessibilityHidden(true)
      Text(text)
        .tollType(.body, TollColor.label)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  /// The same glyphs the state has everywhere else (design §2.6).
  private func stateSymbol(_ state: DayTimeline.Segment.State) -> TollSymbol {
    switch state {
    case .on: .blocked
    case .paused: .unlock
    case .later: .later
    case .ended: .done
    case .off: .off
    case .waiting: .waiting
    case .away: .away
    }
  }

  private func placeSymbol(_ place: DayTimeline.Segment.Place) -> TollSymbol {
    switch place {
    case .home: .home
    case .place: .place
    case .anywhere: .anywhere
    case .needsAlways: .degraded
    }
  }
}
