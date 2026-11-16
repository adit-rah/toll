import Foundation
import TollCore
import TollData

/// What Home's state bar says, in priority order (design §3.18): anything that stops the gate
/// working, then the gate itself, then what the blocks are doing.
enum HomeBarState: Equatable {
  case screenTimeOff
  case needsRepicking([BlockRef])
  case waiting(Wait)
  /// A pass to use: the picker is due, or it was set aside with Not now.
  case choosing(PendingPass)
  case open(BlockState, ActiveSession)
  case blocked(active: [BlockState], next: BlockState?)
  /// `apps`: every app in every block, for the line when no block has days to start on.
  case nothingNow(next: BlockState?, apps: Int)
  case nothingYet

  static func resolve(
    device: HomeModel.DeviceState?, gate: SharedGateState, states: [BlockState], now: Date
  ) -> HomeBarState {
    switch device {
    case .screenTimeOff: return .screenTimeOff
    case .blocksNeedRepicking(let ids): return .needsRepicking(ids)
    case .nothingBlocked: return .nothingYet
    case nil: break
    }
    if let wait = gate.wait { return .waiting(wait) }
    if let pending = gate.pendingPass, !pending.deferred { return .choosing(pending) }
    let active = BlockStates.active(states)
    if let lead = active.first, lead.isOpen,
      let session = gate.sessions.first(where: {
        lead.sessionIDs.contains($0.id) && !$0.isExpired(at: now)
      })
    {
      return .open(lead, session)
    }
    if active.contains(where: \.passReady), let pending = gate.pendingPass {
      return .choosing(pending)
    }
    if states.isEmpty { return .nothingYet }
    let next = BlockStates.next(states)
    if active.isEmpty { return .nothingNow(next: next, apps: apps(of: states).count) }
    return .blocked(active: active, next: next)
  }

  /// Every app the blocks on now cover, once each, in the block list's order.
  static func apps(of states: [BlockState]) -> [AppRef] {
    var refs: [AppRef] = []
    for state in states {
      for ref in state.block.appRefs where !refs.contains(ref) { refs.append(ref) }
    }
    return refs
  }

  /// "Nights": the block's own name when it has one, else its schedule's kind.
  static func name(of block: StoredBlock) -> String {
    if let name = block.name, !name.isEmpty { return name }
    return Copy.Schedules.kind(block.schedule)
  }

  /// The line for a block that is off now: "Nights starts at 11 pm · 5 apps".
  static func startsLine(_ next: BlockState?, apps: Int) -> String {
    guard let next, case .starts(let time) = next.line else { return Copy.Bar.appCount(apps) }
    return Copy.Bar.startsAt(name(of: next.block), time, apps: next.block.appRefs.count)
  }

  /// "Always · 2 more from 11 pm".
  static func blockedLine(_ lead: BlockState?, next: BlockState?) -> String {
    var parts: [String] = []
    if let text = lead?.lineText { parts.append(text) }
    if let next, case .starts(let time) = next.line {
      parts.append(Copy.Bar.moreFrom(next.block.appRefs.count, time))
    }
    return parts.joined(separator: Copy.middleDot)
  }
}
