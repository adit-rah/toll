import SwiftUI
import TollCore
import TollUI

/// The Blocks tab (D63), quieter (D68, #89): the night leads as moon start – end sun over its strip,
/// the other blocks follow as compact rows with "New block" under them, and the limits stay pinned
/// to the bottom (D64, #94). Which block, whether it's on and how full the limits are read from
/// tiles, state glyphs, a bar and pips (#78).
struct BlocksView: View {
  let model: AppModel

  var body: some View {
    let snapshot = BlocksSnapshot(
      state: model.state, now: model.now, calendar: .current, config: model.config,
      screenTime: model.screenTime == .approved)
    GeometryReader { proxy in
      ScrollView {
        page(snapshot)
          .frame(minHeight: proxy.size.height, alignment: .top)
      }
    }
    .background(TollColor.bg)
    .tollPushed(Copy.Blocks.title)
  }

  /// The limits sit at the bottom, as on the board; spare room goes above them.
  private func page(_ snapshot: BlocksSnapshot) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      ScreenTitle(Copy.Blocks.title, kind: .pushed)
      if let night = snapshot.night {
        NavigationLink(value: HomeRoute.block(night.id)) {
          NightCard(night: night)
        }
        .buttonStyle(.plain)
        .padding(.top, TollSpacing.titleToContent)
      }
      Card {
        OtherBlocks(rows: snapshot.others, group: snapshot.group)
        NewBlockRow(limits: snapshot.limits)
      }
      .padding(.top, 12)
      Spacer(minLength: 24)
      LimitsCard(limits: snapshot.limits)
      Footnote(Copy.Blocks.unlocksShared, symbol: .unlock, alignment: .center)
        .padding(.top, TollSpacing.underCard)
    }
    .tollGutter()
    .padding(.bottom, 30)
  }
}

/// The night: its state, moon start – end sun over the strip Tonight draws, and what it holds.
private struct NightCard: View {
  let night: BlocksSnapshot.Night

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        BlockState(state: night.state, text: night.stateText)
        Spacer(minLength: 8)
        Chevron()
      }
      if let picture = night.picture {
        NightPictureView(picture: picture)
      }
      FactLine(night.facts.lines)
    }
    .padding(.vertical, TollSpacing.statsCardVertical)
    .padding(.horizontal, TollSpacing.cardPadding)
    .tollSurface()
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
  }
}

/// "New block", one tap from the tab (#89); off with its reason once the blocks or the time windows
/// are used up.
private struct NewBlockRow: View {
  let limits: BlockLimits

  var body: some View {
    NavigationLink(value: HomeRoute.block(nil)) {
      HStack(spacing: TollSpacing.rowGap) {
        Image(symbol: .add).unredacted()
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(limits.canAddBlock ? TollColor.accent : TollColor.label3)
          .frame(width: TileSize.row.side)
          .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 1) {
          Text(Copy.Blocks.new)
            .tollType(
              TollType(size: 16, lineHeight: 21, weight: .semibold, style: .callout),
              limits.canAddBlock ? TollColor.accent : TollColor.label2)
          if !limits.canAddBlock {
            // Whichever limit is the one that's reached (#49).
            Text(
              limits.blocksUsed >= limits.blocksMax
                ? Copy.Blocks.blocksFull(limits.blocksMax)
                : Copy.Blocks.windowsFullHint(limits.windowsMax)
            )
            .tollType(.detail, TollColor.label2)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(.vertical, 8)
      .frame(minHeight: RowSize.compact.minHeight)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(!limits.canAddBlock)
  }
}

/// The two limits that bite (D39, D40), each as a bar, with the counts in words (#78). Segments are
/// kept for the free nights (#129).
private struct LimitsCard: View {
  let limits: BlockLimits

  var body: some View {
    Card {
      LimitRow(
        symbol: .apps, title: Copy.Blocks.appsAndSites,
        value: Copy.Blocks.used(limits.appsUsed, of: limits.appsMax), full: limits.appsOver > 0
      ) {
        CapacityBar(used: limits.appsUsed, of: limits.appsMax)
      }
      LimitRow(
        symbol: .hours, title: Copy.Blocks.timeWindows,
        value: Copy.Blocks.used(limits.windowsUsed, of: limits.windowsMax),
        full: limits.windowsFull
      ) {
        CapacityBar(used: limits.windowsUsed, of: limits.windowsMax)
      }
    }
  }
}

private struct LimitRow<Meter: View>: View {
  let symbol: TollSymbol
  let title: String
  let value: String
  let full: Bool
  @ViewBuilder let meter: Meter

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Image(symbol: symbol).unredacted()
          .font(.system(size: 14, weight: .medium))
          .foregroundStyle(TollColor.label2)
          .accessibilityHidden(true)
        Text(title).tollType(.rowTitle, TollColor.label)
        Spacer(minLength: 8)
        Text(value).tollType(.action, full ? TollColor.warn : TollColor.label2)
      }
      meter
    }
    .padding(.vertical, 12)
    .accessibilityElement(children: .combine)
  }
}
