import Foundation

/// The limits the blocks screens show where they bite (sticky note s5; D39, D40): apps and sites
/// across all blocks, distinct time windows, and whether one more block fits. The same counts the
/// engine refuses by, so a screen never offers what Save would refuse.
public struct BlockLimits: Equatable, Sendable {
  public var appsUsed: Int
  public var appsMax: Int
  public var windowsUsed: Int
  public var windowsMax: Int
  public var blocksUsed: Int
  public var blocksMax: Int

  /// The state's blocks, with `draft` in place of the block of the same id (or added, if new).
  public init(state: DuskState, draft: Block? = nil, config: TollConfig = .defaults) {
    var blocks = state.blocks
    if let draft { Engine.upsert(draft, in: &blocks) }
    appsUsed = blocks.map(\.appCount).reduce(0, +)
    appsMax = config.blocks.maxApps
    windowsUsed = Engine.scheduledWindows(blocks).count
    windowsMax = config.blocks.maxWindows
    blocksUsed = blocks.count
    blocksMax = config.blocks.max
  }

  public var appsOver: Int { max(0, appsUsed - appsMax) }
  public var windowsFull: Bool { windowsUsed >= windowsMax }
  /// A new block needs a window of its own unless it shares hours, which it can't be known to yet.
  public var canAddBlock: Bool { !windowsFull && blocksUsed < blocksMax }
}
