import Foundation

extension BlocksSnapshot {
  /// The other blocks folded into one row once there are more than `blocks.foldAbove` (#110, from
  /// #89's "2 other blocks · Study on until 5 pm"), so the night leads however many there are. It
  /// opens on a tap, and opens by itself while one of them is on, so a block that's on is never
  /// hidden.
  public struct Group: Equatable, Sendable {
    /// "4 other blocks".
    public var title: String
    /// Each folded block's kind, in the list's order: the row's glyphs say which blocks it holds.
    public var kinds: [Block.Kind]
    /// "Study on until 5:00 pm", as Tonight says it (D73); nil while none is on.
    public var onNow: String?
    /// Whether the group shows its rows when Blocks appears: while one is on.
    public var opensByItself: Bool { onNow != nil }
  }

  static func group(
    _ others: [Row], state: DuskState, calendar: Calendar, config: TollConfig
  ) -> Group? {
    guard others.count > config.blocks.foldAbove else { return nil }
    let on = others.filter { $0.state == .on }.compactMap { row in
      state.runtime.active[row.id].map { (row, $0) }
    }
    // The one that ends last names the time, as on Tonight.
    let onNow = on.max { $0.1 < $1.1 }.map { last, end in
      let time = Copy.time(end, in: calendar)
      return on.count == 1
        ? Copy.Home.otherBlockOn(last.name, until: time)
        : Copy.Home.otherBlocksOn(on.count, until: time)
    }
    return Group(
      title: Copy.Blocks.otherBlocks(others.count), kinds: others.map(\.kind), onNow: onNow)
  }
}
