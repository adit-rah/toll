import SwiftUI
import TollCore
import TollUI

/// The blocks other than the night, on Blocks: compact rows (D73), or, past `blocks.foldAbove`, one
/// row that opens into them (#110). It opens on a tap, and by itself while one is on.
struct OtherBlocks: View {
  let rows: [BlocksSnapshot.Row]
  let group: BlocksSnapshot.Group?
  /// Nil until the person taps: until then the group follows whether a block is on.
  @State private var opened: Bool?
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    if let group {
      let open = opened ?? group.opensByItself
      VStack(spacing: 0) {
        Button {
          withAnimation(reduceMotion ? Motion.stateChange : Motion.movement) { opened = !open }
        } label: {
          GroupRow(group: group, open: open, reduceMotion: reduceMotion)
        }
        .buttonStyle(.plain)
        .accessibilityValue(open ? Copy.Morning.unfolded : Copy.Morning.folded)
        .accessibilityHint(open ? Copy.Blocks.hideBlocksHint : Copy.Blocks.showBlocksHint)
        .accessibilityIdentifier("blocks.group")
        if open {
          ForEach(rows) { row in
            VStack(spacing: 0) {
              Hairline()
              link(row)
            }
            // In after the card has grown for 100 ms, out at once (design §2.5).
            .transition(reduceMotion ? .opacity.animation(Motion.stateChange) : Motion.pageSwap)
          }
        }
      }
    } else {
      ForEach(rows) { link($0) }
    }
  }

  private func link(_ row: BlocksSnapshot.Row) -> some View {
    NavigationLink(value: HomeRoute.block(row.id)) {
      OtherBlockRow(row: row)
    }
    .buttonStyle(.plain)
  }
}

/// The folded group: the stack tile (amber while one is on), "4 other blocks", and under it either
/// the one that's on, with its lock, or the kinds' glyphs, so which blocks it holds reads without
/// words. The chevron points the way the rows open and turns half a turn as they do.
private struct GroupRow: View {
  let group: BlocksSnapshot.Group
  let open: Bool
  let reduceMotion: Bool

  var body: some View {
    BlockRowLayout(title: group.title) {
      IconTile(.blocks, accent: group.onNow != nil)
    } detail: {
      if let onNow = group.onNow {
        FactLine([.init(.blocked, onNow)])
      } else {
        HStack(spacing: 6) {
          ForEach(Array(group.kinds.enumerated()), id: \.offset) { _, kind in
            Image(symbol: .block(kind)).unredacted()
              .font(.system(size: 12, weight: .semibold))
              .foregroundStyle(TollColor.label3)
          }
        }
        .accessibilityHidden(true)
      }
    } trailing: {
      ZStack {
        if reduceMotion {
          chevron(open ? .unfold : .fold)
            .id(open)
            .transition(.opacity.animation(Motion.stateChange))
        } else {
          chevron(.fold).rotationEffect(.degrees(open ? 180 : 0))
        }
      }
    }
    .accessibilityElement(children: .combine)
  }

  private func chevron(_ symbol: TollSymbol) -> some View {
    Image(symbol: symbol).unredacted()
      .font(.system(size: 13, weight: .semibold))
      .foregroundStyle(TollColor.label3)
      .accessibilityHidden(true)
  }
}

/// A block other than the night: its kind's tile (amber while on), name, where and when as glyphed
/// facts (#110), and its state as a glyph and a word.
struct OtherBlockRow: View {
  let row: BlocksSnapshot.Row

  var body: some View {
    BlockRowLayout(title: row.name) {
      IconTile(.block(row.kind), accent: row.state == .on)
    } detail: {
      FactLine(row.facts.lines)
    } trailing: {
      HStack(spacing: 10) {
        BlockState(state: row.state, text: row.stateText)
        Chevron()
      }
    }
    .accessibilityElement(children: .combine)
  }
}

/// A block's state: the glyph first, so it reads without the word (#72, design §2.6).
struct BlockState: View {
  let state: BlocksSnapshot.Row.State
  let text: String

  var body: some View {
    if state != .unscheduled {
      StatusValue(text, symbol: symbol, tone: state == .on ? .accent : .neutral)
    }
  }

  private var symbol: TollSymbol {
    switch state {
    case .on: .blocked
    case .later, .unscheduled: .later
    case .off: .off
    case .waiting: .waiting
    }
  }
}

/// `CardRow` with a detail that isn't one string: the tile, the title over its detail, and the
/// trailing view, which moves under the text at accessibility sizes.
private struct BlockRowLayout<Leading: View, Detail: View, Trailing: View>: View {
  let title: String
  @ViewBuilder let leading: Leading
  @ViewBuilder let detail: Detail
  @ViewBuilder let trailing: Trailing
  @Environment(\.dynamicTypeSize) private var typeSize

  var body: some View {
    let layout =
      typeSize.isAccessibilitySize
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
      : AnyLayout(HStackLayout(spacing: TollSpacing.rowGap))
    layout {
      HStack(spacing: TollSpacing.rowGap) {
        leading
        VStack(alignment: .leading, spacing: 1) {
          Text(title).tollType(.rowTitle, TollColor.label)
          detail
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      trailing
    }
    .padding(.vertical, 8)
    .frame(minHeight: RowSize.list.minHeight)
    .contentShape(Rectangle())
  }
}

extension [BlocksSnapshot.Fact] {
  /// Each fact with its glyph; the days join the hours under one clock, so a line never ends on a
  /// lone "Weekdays".
  var lines: [FactLine.Fact] {
    var lines: [FactLine.Fact] = []
    for (index, fact) in enumerated() {
      if fact.kind == .days, index > 0, self[index - 1].kind == .hours, let hours = lines.popLast()
      {
        lines.append(FactLine.Fact(.hours, Copy.Blocks.hoursOn(hours.text, days: fact.text)))
      } else {
        lines.append(fact.line)
      }
    }
    return lines
  }
}

extension BlocksSnapshot.Fact {
  /// The glyph each fact leads with (design §2.6).
  var line: FactLine.Fact {
    let symbol: TollSymbol? =
      switch kind {
      case .apps: .apps
      case .home: .home
      case .place: .place
      case .anywhere: .anywhere
      case .waiting: .waiting
      case .hours: .hours
      case .days: nil
      case .weekendsDiffer: .weekends
      case .deleting: .delete
      case .changing: .later
      }
    return FactLine.Fact(symbol, text)
  }
}
