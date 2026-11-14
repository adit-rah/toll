import Foundation
import TollCore
import TollData
import TollScreenTime

/// Blocks holding an app the phone no longer has a token for (flows §19). iOS can expire tokens; the
/// shield cannot cover an app without one, so the block needs its apps picked again.
enum StaleBlocks {
  /// The registry is a file in the App Group, read under file coordination: kept off the main actor.
  static func ids(in blocks: [StoredBlock]) async -> Set<BlockRef> {
    #if DEBUG
      if DemoStandIns.active { return [] }
    #endif
    return await Task.detached { () -> Set<BlockRef> in
      let registry = TokenRegistry()
      let stale = blocks.filter { registry.tokens(for: $0.appRefs).count < $0.appRefs.count }
      return Set(stale.map(\.id))
    }.value
  }

  /// The refs of one block that still have a token, in the block's order.
  static func surviving(_ refs: [AppRef]) -> [AppRef] {
    #if DEBUG
      if DemoStandIns.active { return refs }
    #endif
    let registry = TokenRegistry()
    return refs.filter { !registry.tokens(for: [$0]).isEmpty }
  }
}
