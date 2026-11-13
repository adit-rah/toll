import SwiftUI
import TollCore
import TollData
import TollUI

/// The block bar (design §3.18): what the blocks are doing right now, pinned above the tab bar. It
/// is one control, and VoiceOver reads it as one: block, state, action. Tapping it enlarges it into
/// the block cards.
struct ActiveBlockBar: View {
  let summary: BlockBarSummary
  let action: () -> Void
  @Environment(\.dynamicTypeSize) private var typeSize

  private static let minHeight: CGFloat = 56

  var body: some View {
    Button(action: action) {
      HStack(spacing: TollSpacing.rowLeadingGap) {
        AppIconCluster(summary.appRefs)
        VStack(alignment: .leading, spacing: 2) {
          title
          BlockStateLine(state: summary.lead)
          // At accessibility sizes the action goes beneath, so the names keep the bar's width.
          if typeSize.isAccessibilitySize { actionLabel }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        if !typeSize.isAccessibilitySize { actionLabel }
      }
      .padding(.horizontal, TollSpacing.cardPadding)
      .padding(.vertical, TollSpacing.labelGap)
      .frame(minHeight: Self.minHeight)
      .contentShape(RoundedRectangle(cornerRadius: TollRadius.card, style: .continuous))
      .modifier(BlockBarSurface())
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(summary.lead.isOpen ? .updatesFrequently : [])
  }

  /// Several blocks on: the bar counts them and the cards name them. Nothing on: the next block to
  /// start, in the secondary tier because there is nothing to act on.
  @ViewBuilder
  private var title: some View {
    if summary.activeCount > 1 {
      Text(Copy.ActiveBlock.blocksOn(summary.activeCount))
        .font(TollFont.bodyMedium)
        .foregroundStyle(TollColor.label)
        .monospacedDigit()
        .lineLimit(1)
    } else {
      BlockTitle(block: summary.lead.block)
        .font(summary.activeCount > 0 ? TollFont.bodyMedium : TollFont.body)
        .foregroundStyle(summary.activeCount > 0 ? TollColor.label : TollColor.label2)
    }
  }

  @ViewBuilder
  private var actionLabel: some View {
    if let title = summary.actionTitle {
      Text(title)
        .font(TollFont.bodyMedium)
        .foregroundStyle(TollColor.accent)
        .lineLimit(1)
    }
  }
}

/// A floating control, the one place the design allows glass (§1.7). Before iOS 26 it is the fill
/// that differs from the page (§2.1) with a hairline.
private struct BlockBarSurface: ViewModifier {
  @Environment(\.displayScale) private var displayScale

  func body(content: Content) -> some View {
    let outline = RoundedRectangle(cornerRadius: TollRadius.card, style: .continuous)
    if #available(iOS 26, *) {
      content.glassEffect(.regular, in: outline)
    } else {
      content
        .background(TollColor.surfaceRaised, in: outline)
        .overlay { outline.strokeBorder(TollColor.separator, lineWidth: 1 / displayScale) }
    }
  }
}

/// The block's own name when it has one, else its apps' names from the system.
struct BlockTitle: View {
  let block: StoredBlock

  var body: some View {
    if let name = block.name, !name.isEmpty {
      Text(name).lineLimit(1)
    } else {
      AppNames(block.appRefs)
    }
  }
}

/// The state line under a block's title, on the bar and on the cards (design §3.18).
struct BlockStateLine: View {
  let state: BlockState

  var body: some View {
    if case .open(let until) = state.line {
      SessionCountdown(endsAt: until)
    } else if let text = state.lineText {
      Text(text)
        .tollText(.subhead)
        .monospacedDigit()
        .contentTransition(.numericText())
        .animation(Motion.movement, value: text)
    }
  }
}
