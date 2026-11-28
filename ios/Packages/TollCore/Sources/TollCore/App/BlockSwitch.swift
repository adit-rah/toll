import Foundation

/// A block's on/off switch (#161; founder: "yes, but not during the block"). Only blocks other than
/// the night have one: the night is the product. Off can't be chosen inside the block's hours, so a
/// switch is never the way out of a block that's on; on can be chosen any time, and inside the hours
/// it waits for the next start rather than locking mid-way (B-3, B-4).
public struct BlockSwitch: Equatable, Sendable {
  /// As saved.
  public var isOn: Bool
  /// Inside its hours while on: the switch holds until they end, then it can be turned off.
  public var offAfter: Date?
  /// Inside its hours: turned on now, it first locks at this start.
  public var startsAt: Date?

  /// Nil for the night, which has no switch.
  public init?(_ block: Block, now: Date, calendar: Calendar) {
    guard !block.isSleep else { return nil }
    isOn = block.isOn
    let inside = block.schedule.occurrence(containing: now, calendar: calendar)
    offAfter = block.isOn ? inside?.end : nil
    startsAt =
      !block.isOn && inside != nil
      ? block.schedule.nextStart(after: inside?.end ?? now, calendar: calendar) : nil
  }

  public var canTurnOff: Bool { offAfter == nil }

  /// What saving `block` over what's stored does to the switch: refused when it would turn the
  /// night off, or another block off inside its hours. Turned on inside its hours, the hours it's
  /// in are counted as ended (B-4), so it first locks at its next start.
  static func save(
    _ block: Block, over stored: Block?, in state: inout DuskState, now: Date, calendar: Calendar
  ) -> CommandError? {
    guard let stored, stored.isOn != block.isOn else { return nil }
    if !block.isOn {
      if block.isSleep { return .cannotSwitchOff }
      return BlockSwitch(stored, now: now, calendar: calendar)?.canTurnOff == false
        ? .cannotSwitchOff : nil
    }
    if block.schedule.occurrence(containing: now, calendar: calendar) != nil {
      state.runtime.lastEnd[block.id] = max(state.runtime.lastEnd[block.id] ?? now, now)
    }
    return nil
  }
}
