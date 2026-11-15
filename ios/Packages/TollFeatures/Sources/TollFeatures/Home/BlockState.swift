import Foundation
import TollCore
import TollData

/// What Home's state bar and its sheet show for one block (design §3.18).
struct BlockState: Equatable, Identifiable {
  /// The line beside the block, resolved as far as a clock time so the views need no calendar.
  enum Line: Equatable {
    case always
    case until(ClockTime)
    case open(until: Date)
    case passReady
    case starts(ClockTime)
    /// A block with no days is never on; its schedule is all there is to say.
    case unscheduled
  }

  var block: StoredBlock
  var phase: BlockPhase
  var line: Line
  /// Every live session covering one of the block's apps. "Lock now" ends them all: ending only one
  /// would leave the block reading as open.
  var sessionIDs: [UUID]

  var id: BlockRef { block.id }
  var passReady: Bool { line == .passReady }

  var isOpen: Bool {
    if case .open = phase { return true }
    return false
  }

  var isOn: Bool {
    if case .on = phase { return true }
    return false
  }

  var startsAt: Date? {
    if case .off(let from) = phase { return from }
    return nil
  }

  /// Nil while a session is open: that line ticks, so it is drawn, not stored.
  var lineText: String? {
    switch line {
    case .always: Copy.ActiveBlock.always
    case .until(let time): Copy.ActiveBlock.until(time)
    case .passReady: Copy.ActiveBlock.passReady
    case .starts(let time): Copy.ActiveBlock.starts(time)
    case .open, .unscheduled: nil
    }
  }
}

enum BlockStates {
  static func resolve(
    blocks: [StoredBlock], gate: SharedGateState, at now: Date, math: DayMath
  ) -> [BlockState] {
    let ready = readyPass(in: gate, at: now, math: math)
    return blocks.map { block in
      let phase = BlockStatus.phase(
        of: block.definition, sessions: gate.sessions, at: now, math: math)
      let refs = Set(block.appRefs)
      var sessionIDs: [UUID] = []
      let line: BlockState.Line
      switch phase {
      case .open(let until):
        line = .open(until: until)
        sessionIDs = gate.sessions
          .filter { !$0.isExpired(at: now) && !refs.isDisjoint(with: $0.appRefs) }
          .map(\.id)
      case .on(let until):
        if let ready, covers(ready, block: block, refs: refs) {
          line = .passReady
        } else if let until {
          line = .until(math.clockTime(of: until))
        } else {
          line = .always
        }
      case .off(let from):
        if let from {
          line = .starts(math.clockTime(of: from))
        } else {
          line = .unscheduled
        }
      }
      return BlockState(block: block, phase: phase, line: line, sessionIDs: sessionIDs)
    }
  }

  /// Blocks that are on or open, most urgent first (design §3.18): an open session, then a pass
  /// that is ready, then a block that is on; ties keep the block list's order.
  static func active(_ states: [BlockState]) -> [BlockState] {
    let active = states.filter { $0.isOpen || $0.isOn }
    return active.filter(\.isOpen) + active.filter(\.passReady)
      + active.filter { !$0.isOpen && !$0.passReady }
  }

  /// Blocks outside their window, in the block list's order.
  static func idle(_ states: [BlockState]) -> [BlockState] {
    states.filter { !$0.isOpen && !$0.isOn }
  }

  /// The block outside its window that starts soonest.
  static func next(_ states: [BlockState]) -> BlockState? {
    states.filter { $0.startsAt != nil }
      .min { ($0.startsAt ?? .distantFuture) < ($1.startsAt ?? .distantFuture) }
  }

  /// The next moment any state changes by itself: a window's edge, a session's end, or the day
  /// reset that takes a set-aside pass with it.
  static func nextChange(
    _ states: [BlockState], gate: SharedGateState, after now: Date, math: DayMath
  ) -> Date? {
    var moments = gate.sessions.map(\.expiresAt)
    for state in states {
      switch state.phase {
      case .open(let until): moments.append(until)
      case .on(let until): if let until { moments.append(until) }
      case .off(let from): if let from { moments.append(from) }
      }
    }
    if let pending = gate.pendingPass, pending.deferred {
      moments.append(math.end(of: math.day(containing: now)))
    }
    return moments.filter { $0 > now }.min()
  }

  /// A pass set aside with "Not now" lasts until the day reset. The gate drops it the next time it
  /// runs; until then it must not read as ready.
  private static func readyPass(
    in gate: SharedGateState, at now: Date, math: DayMath
  ) -> PendingPass? {
    guard let pending = gate.pendingPass, pending.deferred else { return nil }
    return math.day(containing: pending.grantedAt) == math.day(containing: now) ? pending : nil
  }

  private static func covers(_ pass: PendingPass, block: StoredBlock, refs: Set<AppRef>) -> Bool {
    if let ref = pass.blockRef { return ref == block.id }
    return !refs.isDisjoint(with: pass.appRefs)
  }
}
