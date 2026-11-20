import Foundation

/// The Blocks screen (the canvas's Blocks): one row per block and the limits under them.
public struct BlocksSnapshot: Equatable, Sendable {
  public struct Row: Equatable, Sendable, Identifiable {
    public var id: BlockID
    public var name: String
    public var kind: Block.Kind
    /// "On now" leads the line in amber while the block is on.
    public var onNow: Bool
    /// "4 apps · Home · 10:30 pm – 7:00 am", or "until 5:00 pm · Robarts Library" while on.
    public var detail: String
    /// The tile is amber for Sleep and for a block that is on.
    public var accent: Bool
  }

  public var rows: [Row]
  public var limits: BlockLimits

  public init(state: DuskState, calendar: Calendar, config: TollConfig = .defaults) {
    rows = state.blocks.map { block in
      let place = state.place(block.place)?.name
      if let end = state.runtime.active[block.id] {
        let parts = [Copy.Blocks.onNowUntil(Copy.time(end, in: calendar)), place].compactMap { $0 }
        return Row(
          id: block.id, name: block.name, kind: block.kind, onNow: true,
          detail: parts.joined(separator: Copy.middleDot), accent: true)
      }
      var parts = [Copy.Blocks.appCount(block.appCount + block.categoryCount)]
      if let place { parts.append(place) }
      if let window = block.schedule.windows.first {
        parts.append(Copy.span(window, in: calendar))
      }
      return Row(
        id: block.id, name: block.name, kind: block.kind, onNow: false,
        detail: parts.joined(separator: Copy.middleDot), accent: block.isSleep)
    }
    limits = BlockLimits(state: state, config: config)
  }
}
