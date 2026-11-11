import Foundation

/// What a block is doing right now, for the line Toll shows beside it.
public enum BlockPhase: Equatable, Sendable {
  /// A session has some of its apps unlocked until then.
  case open(until: Date)
  /// The shield is in effect until the window ends; nil for a block that is always on.
  case on(until: Date?)
  /// Outside its window; the next start, or nil for a block with no days.
  case off(from: Date?)
}

public enum BlockStatus {
  /// A session cannot outlive the window (G-7a), so one that is still persisted past the window's end
  /// reads as off, and one that would run past it is open only until the window ends.
  public static func phase(
    of block: BlockDefinition, sessions: [ActiveSession], at date: Date, math: DayMath
  ) -> BlockPhase {
    let edge = block.schedule.nextTransition(after: date, in: math)
    guard block.schedule.isActive(at: date, in: math) else { return .off(from: edge) }
    let refs = Set(block.appRefs)
    let live = sessions.filter { !$0.isExpired(at: date) && !refs.isDisjoint(with: $0.appRefs) }
    guard let last = live.map(\.expiresAt).max() else { return .on(until: edge) }
    return .open(until: edge.map { min($0, last) } ?? last)
  }
}
