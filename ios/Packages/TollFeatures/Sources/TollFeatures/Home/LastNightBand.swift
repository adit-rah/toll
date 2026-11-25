import SwiftUI
import TollCore
import TollUI

/// Last night in Tonight's band each morning, folded to one quiet row (founder, 25 Nov; amends D91):
/// the moon, "Last night", the night's outcome as a glyph and a few words, and a chevron. The whole
/// row opens the full card, which grows up from it while its bottom edge stays above the strip; the
/// header folds it again. "OK" lives only in the open card. Nothing is kept: the row is folded each
/// time Tonight appears.
struct LastNightBand: View {
  let night: Morning
  @Binding var open: Bool
  let putAway: () -> Void
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private var shape: RoundedRectangle {
    RoundedRectangle(cornerRadius: TollRadius.card, style: .continuous)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      header
      if open {
        LastNightDetails(night: night)
          .padding(.top, 2)
          .padding(.bottom, TollSpacing.noteCardVertical)
          .transition(.content(reduceMotion: reduceMotion))
      }
    }
    .padding(.horizontal, TollSpacing.cardPadding)
    .frame(maxWidth: .infinity, alignment: .leading)
    // One surface whose height follows the content; nothing shows outside it while it grows or
    // shrinks, so the card is seen to grow from the row rather than its words arriving first.
    .background(TollColor.surface, in: shape)
    .clipShape(shape)
  }

  /// The row, and the open card's header: one button that opens or folds, with "OK" over the room
  /// kept for it beside the chevron once open. The chevron is one view in both, so it turns with
  /// the card instead of being swapped for another.
  private var header: some View {
    Button(action: toggle) {
      HStack(spacing: 8) {
        summary.frame(maxWidth: .infinity, alignment: .leading)
        if open { ok.hidden() }
        chevron
      }
      .padding(.vertical, 12)
      .contentShape(Rectangle())
    }
    .buttonStyle(.tollPressable)
    .accessibilityLabel(night.statusSpoken)
    .accessibilityValue(open ? Copy.Morning.unfolded : Copy.Morning.folded)
    .accessibilityHint(open ? Copy.Morning.foldHint : Copy.Morning.unfoldHint)
    .accessibilityIdentifier("tonight.lastNight")
    .overlay(alignment: .trailing) {
      if open {
        Button(action: putAway) { ok }
          .frame(minHeight: TollSpacing.minTapTarget)
          .contentShape(Rectangle())
          .padding(.trailing, Self.chevronWidth + 8)
          .transition(.content(reduceMotion: reduceMotion))
      }
    }
  }

  private static let chevronWidth: CGFloat = 14

  private var ok: some View {
    Text(Copy.Morning.ok)
      .tollType(.action, TollColor.label2)
      .frame(minWidth: TollSpacing.minTapTarget)
  }

  /// `chevron.up` turned half a turn as the card opens, which is `chevron.down` (design §2.6); with
  /// Reduce Motion the two crossfade instead of turning.
  @ViewBuilder private var chevron: some View {
    Group {
      if reduceMotion {
        glyph(open ? .fold : .unfold)
          .id(open)
          .transition(.opacity.animation(Motion.stateChange))
      } else {
        glyph(.unfold).rotationEffect(.degrees(open ? 180 : 0))
      }
    }
    .frame(width: Self.chevronWidth)
  }

  /// "☾ Last night  🔒 Locked 8 h 45 m" on one line when it fits, else the status under the title,
  /// wrapping rather than truncating. Open, the card's own sentence says the rest.
  private var summary: some View {
    ViewThatFits(in: .horizontal) {
      HStack(alignment: .firstTextBaseline, spacing: 10) {
        title
        if !open { status.fixedSize().transition(.content(reduceMotion: reduceMotion)) }
      }
      VStack(alignment: .leading, spacing: 4) {
        title
        if !open { status.transition(.content(reduceMotion: reduceMotion)) }
      }
    }
  }

  private var title: some View {
    HStack(alignment: .firstTextBaseline, spacing: 6) {
      glyph(.sleep)
      Text(night.eyebrow)
        .tollType(.body, TollColor.label2)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var status: some View {
    HStack(alignment: .firstTextBaseline, spacing: 6) {
      glyph(statusSymbol)
      Text(night.status)
        .tollType(.body, TollColor.label)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  /// The night's outcome in a glyph, so the row reads without its words (design §5): locked hours,
  /// away, or Screen Time.
  private var statusSymbol: TollSymbol {
    switch night.outcome {
    case .ran: .blocked
    case .away: .away
    case .noScreenTime: .screenTime
    }
  }

  private func glyph(_ symbol: TollSymbol) -> some View {
    Image(symbol: symbol).unredacted()
      .font(.system(size: 13, weight: .semibold))
      .foregroundStyle(TollColor.label2)
      .accessibilityHidden(true)
  }

  /// Design §2.5: it grows up from its row over 300 ms, or with Reduce Motion the content
  /// crossfades and nothing moves.
  private func toggle() {
    if reduceMotion {
      open.toggle()
    } else {
      withAnimation(Motion.movement) { open.toggle() }
    }
  }
}
