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

  /// One surface whose height animates, with the header and the details laid out in it in both
  /// states and clipped to it. Inserted, the details would land at once where the open card ends
  /// and the header would slide up through their words; laid out all along, they ride the card's
  /// top edge with the header and come into view from its bottom edge as it grows. The header
  /// keeps one layout too: what differs between the row and the open card only fades.
  var body: some View {
    FoldLayout(open: open) {
      header
      LastNightDetails(night: night)
        .padding(.top, 2)
        .padding(.bottom, TollSpacing.noteCardVertical)
        .shown(open, reduceMotion: reduceMotion)
    }
    .padding(.horizontal, TollSpacing.cardPadding)
    .frame(maxWidth: .infinity, alignment: .leading)
    // The one surface, its hairline with it, sized by the layout's animated height.
    .tollSurface(shape)
    .clipShape(shape)
  }

  /// The row, and the open card's header: one button that opens or folds, with "OK" over it beside
  /// the chevron once open. The chevron is one view in both, so it turns with the card instead of
  /// being swapped for another.
  private var header: some View {
    Button(action: toggle) {
      HStack(spacing: 8) {
        summary.frame(maxWidth: .infinity, alignment: .leading)
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
    // Over the room the row's status leaves; the two are never shown together.
    .overlay(alignment: .trailing) {
      Button(Copy.Morning.ok, action: putAway)
        .tollType(.action, TollColor.label2)
        .frame(minWidth: TollSpacing.minTapTarget, minHeight: TollSpacing.minTapTarget)
        .contentShape(Rectangle())
        .padding(.trailing, Self.chevronWidth + 8)
        .shown(open, reduceMotion: reduceMotion)
    }
  }

  private static let chevronWidth: CGFloat = 14

  /// `chevron.up` turned half a turn as the card opens, which is `chevron.down` (design §2.6); with
  /// Reduce Motion the two crossfade instead of turning.
  private var chevron: some View {
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
  /// wrapping rather than truncating. Open, a status on the title's line fades and keeps its room,
  /// so the header doesn't reflow; the card's own sentence says the rest.
  private var summary: some View {
    ViewThatFits(in: .horizontal) {
      HStack(alignment: .firstTextBaseline, spacing: 10) {
        title
        status.fixedSize().shown(!open, reduceMotion: reduceMotion)
      }
      // On lines of its own the status would leave the open header with lines of empty room, so
      // here its room closes with the card's curve as it fades. Removed instead, it would hold its
      // room until its fade ended and then give it up in one frame.
      VStack(alignment: .leading, spacing: open ? 0 : 4) {
        title
        status
          .shown(!open, reduceMotion: reduceMotion)
          .frame(height: open ? 0 : nil, alignment: .top)
          .clipped()
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
      .tollGlyph(13, weight: .semibold)
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

extension View {
  /// A part of last night's card that comes or goes as it opens or folds (design §2.5): it fades
  /// in after the first 100 ms and out at once, and while hidden it's neither tapped nor heard.
  /// Only its opacity takes that timing: its place follows the card's edge on the card's curve.
  fileprivate func shown(_ shown: Bool, reduceMotion: Bool) -> some View {
    animation(shown ? (reduceMotion ? Motion.stateChange : Motion.contentIn) : Motion.contentOut) {
      $0.opacity(shown ? 1 : 0)
    }
    .allowsHitTesting(shown)
    .accessibilityHidden(!shown)
  }
}

/// The header over the details, at the size of the header alone while folded: the details keep
/// their place under it, past the card's clipped bottom edge, so opening only changes the height.
/// A layout rather than a measured height, so the first frame is already right.
private struct FoldLayout: Layout {
  let open: Bool

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let fit = ProposedViewSize(width: proposal.width, height: nil)
    let heights = subviews.map { $0.sizeThatFits(fit).height }
    let width = proposal.width ?? subviews.map { $0.sizeThatFits(fit).width }.max() ?? 0
    return CGSize(width: width, height: open ? heights.reduce(0, +) : heights.first ?? 0)
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    var y = bounds.minY
    for subview in subviews {
      let height = subview.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil)).height
      subview.place(
        at: CGPoint(x: bounds.minX, y: y), anchor: .topLeading,
        proposal: ProposedViewSize(width: bounds.width, height: height))
      y += height
    }
  }
}
