import Foundation

/// Tonight's reason when this week's start isn't the person's own (D65): one short line under the
/// lock's time, in the place the minutes before sleep take on other weeks, so the time never moves
/// (D105). Nil on the person's own time, and once the lock is on.
public struct HeldStart: Equatable, Sendable {
  /// Minutes from the person's own start: negative is earlier.
  public var offset: Int
  /// The week settled on what the model found (D66) and the insight is on Your sleep (#182): the
  /// line points to it instead of to learning.
  public var found: Bool
  public var text: String
  public var spoken: String

  /// The start in force is the one Tonight's time shows (`DuskState.lead`), so the line and the
  /// time always agree. A week drawn to learn says so even if an insight shows mid-week, and a
  /// settled week whose insight stops holding goes back to it: until Sunday's night ends, its
  /// start is only being tried.
  public init?(_ state: DuskState, insight: ModelReading.Insight? = nil) {
    guard state.timing.on, let hold = state.timing.inForce, hold.offset != 0 else { return nil }
    offset = hold.offset
    found = hold.settled && insight?.supports(hold.offset) == true
    text = found ? Copy.Timing.heldFound(hold.offset) : Copy.Timing.held(hold.offset)
    spoken =
      found ? Copy.Timing.heldFoundSpoken(hold.offset) : Copy.Timing.heldSpoken(hold.offset)
  }
}

/// Settings › Sleep's switch for personal timing (#171). The model learns only from Health's
/// sleep (D65), so without Health the row says so and offers it instead of a switch.
public struct TimingSetting: Equatable, Sendable {
  public enum Kind: Equatable, Sendable {
    case needsHealth, off, on
  }

  public var kind: Kind
  /// What the row says under its title: what it does, what it needs, or this week's start.
  public var detail: String
  /// What it does, for a switch turned on or off and not saved yet.
  public var about: String

  public init(_ state: DuskState, config: TollConfig = .defaults) {
    about = Copy.Timing.rowDetail(config.timing.mostMinutes)
    if !state.health {
      kind = .needsHealth
      detail = Copy.Timing.rowNeedsHealth
    } else if state.timing.on {
      kind = .on
      detail = Copy.Timing.thisWeek(state.timing.inForce?.offset ?? 0)
    } else {
      kind = .off
      detail = about
    }
  }
}
