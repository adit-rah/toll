import SwiftUI
import TollCore
import TollData
import TollUI

/// The block bar enlarged (design §3.18): a card for each block that is on or open, most urgent
/// first, then the blocks outside their windows as plain rows. It reads the model itself so a card
/// changes in place when its block does ("Block again" turns the card back into one with Unblock).
struct BlockCardsSheet: View {
  let model: HomeModel
  let onUnblock: (BlockState) -> Void
  let onBlockAgain: (BlockState) -> Void
  let onEdit: (BlockRef) -> Void
  let onBlocks: () -> Void

  var body: some View {
    let active = BlockStates.active(model.blockStates)
    let idle = BlockStates.idle(model.blockStates)
    ScrollView {
      VStack(spacing: TollSpacing.cardPadding) {
        ForEach(active) { state in
          ActiveBlockCard(
            state: state, onUnblock: { onUnblock(state) }, onBlockAgain: { onBlockAgain(state) },
            onEdit: { onEdit(state.id) })
        }
        if !idle.isEmpty {
          VStack(spacing: 0) {
            ForEach(idle) { state in
              BlockRow(
                schedule: state.lineText ?? Copy.Schedules.label(state.block.schedule),
                showsChevron: false
              ) {
                AppIconCluster(state.block.appRefs)
              } names: {
                BlockTitle(block: state.block)
              }
            }
          }
        }
        QuietButton(Copy.Blocks.title, tone: .secondary, action: onBlocks)
      }
      .tollGutter()
      .padding(.top, TollSpacing.sectionGap)
      .padding(.bottom, TollSpacing.footerBottom)
    }
    .scrollBounceBehavior(.basedOnSize)
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
  }
}

/// One block's card: what it covers, what it is doing, and the one thing to do about it.
struct ActiveBlockCard: View {
  let state: BlockState
  let onUnblock: () -> Void
  let onBlockAgain: () -> Void
  let onEdit: () -> Void

  private static let shownApps = 5
  private static let appRowHeight: CGFloat = 36

  var body: some View {
    VStack(spacing: 0) {
      header
      status
      Hairline()
        .padding(.top, TollSpacing.cardPadding)
        .padding(.bottom, TollSpacing.labelGap)
      apps
      action
        .padding(.top, TollSpacing.cardPadding)
      QuietButton(Copy.Settings.edit, tone: .secondary, action: onEdit)
    }
    .padding([.horizontal, .top], TollSpacing.cardPadding)
    // The quiet button's 44 pt box already carries 11 pt of air under its label.
    .padding(.bottom, TollSpacing.labelGap)
    .frame(maxWidth: .infinity)
    // `surfaceRaised`: the sheet is `bg`, and a card's fill must differ from its page (§2.1).
    .background(
      TollColor.surfaceRaised,
      in: RoundedRectangle(cornerRadius: TollRadius.card, style: .continuous))
  }

  private var header: some View {
    HStack(spacing: TollSpacing.rowLeadingGap) {
      AppIconCluster(state.block.appRefs)
      VStack(alignment: .leading, spacing: 2) {
        BlockTitle(block: state.block)
          .font(TollFont.headline)
          .foregroundStyle(TollColor.label)
        Text(Copy.Schedules.label(state.block.schedule))
          .tollText(.caption)
          .monospacedDigit()
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(.isHeader)
  }

  /// Open: the countdown, centred like the wait card's. An always-on block says nothing here, since
  /// the schedule line above has just said "Always".
  @ViewBuilder
  private var status: some View {
    if case .open(let until) = state.line {
      VStack(spacing: 0) {
        Text(Copy.ActiveBlock.open).tollText(.subhead)
        SessionCountdown(endsAt: until, style: .numeral)
      }
      .frame(maxWidth: .infinity)
      .padding(.top, TollSpacing.cardPadding)
      .accessibilityElement(children: .combine)
    } else if state.line != .always {
      BlockStateLine(state: state)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, TollSpacing.cardPadding)
    }
  }

  private var apps: some View {
    let refs = state.block.appRefs
    return VStack(alignment: .leading, spacing: 0) {
      ForEach(Array(refs.prefix(Self.shownApps)), id: \.self) { ref in
        AppLabel(ref, style: .both)
          .tollText(.body)
          .lineLimit(1)
          .frame(maxWidth: .infinity, minHeight: Self.appRowHeight, alignment: .leading)
      }
      if refs.count > Self.shownApps {
        Text(Copy.BlockEditor.more(refs.count - Self.shownApps))
          .tollText(.caption)
          .monospacedDigit()
          .frame(minHeight: Self.appRowHeight)
      }
    }
  }

  @ViewBuilder
  private var action: some View {
    if state.isOpen {
      Button(Copy.ActiveBlock.blockAgain, action: onBlockAgain)
        .buttonStyle(.tollSecondary)
    } else {
      PrimaryButton(Copy.ActiveBlock.unblock, action: onUnblock)
    }
  }
}
