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
          // Design §2.5: the content fades in once the card has begun to grow.
          .transition(
            .asymmetric(
              insertion: .opacity.animation(
                reduceMotion ? Motion.stateChange : Motion.unfoldContent),
              removal: .opacity.animation(Motion.stateChange)))
      }
    }
    .padding(.horizontal, TollSpacing.cardPadding)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(TollColor.surface, in: shape)
    // While it grows or shrinks, nothing shows outside the card.
    .clipShape(shape)
  }

  /// The row, and the open card's header: one button that opens or folds, with "OK" beside the
  /// chevron once open.
  private var header: some View {
    HStack(spacing: 0) {
      Button(action: toggle) {
        HStack(spacing: 8) {
          summary.frame(maxWidth: .infinity, alignment: .leading)
          if !open { glyph(.unfold) }
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
      }
      .buttonStyle(.tollPressable)
      .accessibilityLabel(night.statusSpoken)
      .accessibilityValue(open ? Copy.Morning.unfolded : Copy.Morning.folded)
      .accessibilityHint(open ? Copy.Morning.foldHint : Copy.Morning.unfoldHint)
      .accessibilityIdentifier("tonight.lastNight")
      if open {
        Button(Copy.Morning.ok, action: putAway)
          .tollType(.action, TollColor.label2)
          .frame(minWidth: TollSpacing.minTapTarget, minHeight: TollSpacing.minTapTarget)
          .contentShape(Rectangle())
        // The chevron folds it too; VoiceOver has the row for that.
        Button(action: toggle) {
          glyph(.fold)
            .frame(minWidth: 28, minHeight: TollSpacing.minTapTarget, alignment: .trailing)
            .contentShape(Rectangle())
        }
        .buttonStyle(.tollPressable)
        .accessibilityHidden(true)
      }
    }
  }

  /// "☾ Last night  🔒 Locked 8 h 45 m" on one line when it fits, else the status under the title,
  /// wrapping rather than truncating. Open, the card's own sentence says the rest.
  private var summary: some View {
    ViewThatFits(in: .horizontal) {
      HStack(alignment: .firstTextBaseline, spacing: 10) {
        title
        if !open { status.fixedSize() }
      }
      VStack(alignment: .leading, spacing: 4) {
        title
        if !open { status }
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
