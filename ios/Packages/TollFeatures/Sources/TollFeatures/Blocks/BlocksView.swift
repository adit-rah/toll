import SwiftUI
import TollCore
import TollUI

/// Blocks (the canvas's Blocks, and Blocks · 8 time windows), pushed from Home: every block, a new
/// one, and the two limits that bite (D39, D40).
struct BlocksView: View {
  let model: AppModel

  var body: some View {
    let snapshot = BlocksSnapshot(state: model.state, calendar: .current, config: model.config)
    let compact = snapshot.rows.count > 4
    GeometryReader { proxy in
      ScrollView {
        page(snapshot: snapshot, compact: compact)
          .frame(minHeight: proxy.size.height, alignment: .top)
      }
    }
    .background(TollColor.bg)
    .tollPushed(Copy.Blocks.title)
  }

  /// The limits sit at the bottom, as on the board; spare room goes above them.
  private func page(snapshot: BlocksSnapshot, compact: Bool) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      ScreenTitle(Copy.Blocks.title, kind: .pushed)
      if !compact {
        SetupLine(Copy.Blocks.line).padding(.top, 8)
      }
      Card {
        ForEach(snapshot.rows) { row in
          NavigationLink(value: HomeRoute.block(row.id)) {
            BlockListRow(row: row, compact: compact)
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.top, compact ? 16 : 24)
      NewBlockRow(limits: snapshot.limits).padding(.top, 12)
      Spacer(minLength: 24)
      Card {
        LimitRow(
          title: Copy.Blocks.appsAndSites,
          value: Copy.Blocks.used(snapshot.limits.appsUsed, of: snapshot.limits.appsMax),
          full: snapshot.limits.appsOver > 0)
        LimitRow(
          title: Copy.Blocks.timeWindows,
          value: Copy.Blocks.used(snapshot.limits.windowsUsed, of: snapshot.limits.windowsMax),
          full: snapshot.limits.windowsFull)
      }
      Footnote(Copy.Blocks.unlocksShared, alignment: .center).padding(.top, TollSpacing.underCard)
    }
    .tollGutter()
    .padding(.bottom, 30)
  }
}

/// 72 pt with a 40 pt tile; 56 pt with a 36 pt tile once the list is long.
private struct BlockListRow: View {
  let row: BlocksSnapshot.Row
  let compact: Bool

  var body: some View {
    HStack(spacing: TollSpacing.rowGap) {
      IconTile(BlockSymbol.name(row.kind), size: compact ? .row : .large, accent: row.accent)
      VStack(alignment: .leading, spacing: 1) {
        Text(row.name).tollType(.rowTitle, TollColor.label)
        (row.onNow
          ? Text(
            "\(Text(Copy.Home.onNow).foregroundStyle(TollColor.accent).fontWeight(.semibold))\(Copy.middleDot)\(row.detail)"
          )
          : Text(row.detail))
          .tollType(.detail, TollColor.label2)
      }
      .fixedSize(horizontal: false, vertical: true)
      .frame(maxWidth: .infinity, alignment: .leading)
      Chevron()
    }
    .padding(.vertical, 8)
    .frame(minHeight: compact ? 56 : 72)
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
  }
}

/// "New block", off with its reason once the blocks or the time windows are used up.
private struct NewBlockRow: View {
  let limits: BlockLimits

  var body: some View {
    Card {
      NavigationLink(value: HomeRoute.block(nil)) {
        HStack(spacing: TollSpacing.rowGap) {
          Image(systemName: "plus")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(limits.canAddBlock ? TollColor.accent : TollColor.label3)
            .frame(width: 40)
            .accessibilityHidden(true)
          VStack(alignment: .leading, spacing: 1) {
            Text(Copy.Blocks.new)
              .tollType(
                TollType(size: 16, lineHeight: 21, weight: .semibold, style: .callout),
                limits.canAddBlock ? TollColor.accent : TollColor.label3)
            if !limits.canAddBlock {
              // Whichever limit is the one that's reached (#49).
              Text(
                limits.blocksUsed >= limits.blocksMax
                  ? Copy.Blocks.blocksFull(limits.blocksMax)
                  : Copy.Blocks.windowsFull(limits.windowsMax)
              )
              .tollType(.detail, TollColor.label2)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8)
        .frame(minHeight: 60)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .disabled(!limits.canAddBlock)
    }
  }
}

private struct LimitRow: View {
  let title: String
  let value: String
  let full: Bool

  var body: some View {
    HStack {
      Text(title).tollType(.rowTitle, TollColor.label)
      Spacer()
      Text(value).tollType(.action, full ? TollColor.warn : TollColor.label2)
    }
    .frame(minHeight: 46)
    .accessibilityElement(children: .combine)
  }
}
