import Foundation

/// What must happen outside the state after a reconcile (docs/architecture.md). Data, not calls: the
/// coordinator hands each part to its port, and tests read it.
public struct Effects: Hashable, Sendable {
  /// Always present: reconcile decides the whole shield every time (B-5).
  public var shield: ShieldPlan
  /// Set only when the windows to monitor changed.
  public var windows: [TimeWindow]?
  public var door: DoorSchedulePlan?
  /// The places the app should be watching; the region adapter compares and changes only what differs.
  public var places: [Place]
  public var log: Transition?

  public init(
    shield: ShieldPlan, windows: [TimeWindow]? = nil, door: DoorSchedulePlan? = nil,
    places: [Place] = [], log: Transition? = nil
  ) {
    self.shield = shield
    self.windows = windows
    self.door = door
    self.places = places
    self.log = log
  }
}

/// The shield as a whole: every active block's selection, or nothing while a pause is open (D67).
public struct ShieldPlan: Hashable, Sendable {
  public var selections: [Data]

  public init(selections: [Data]) {
    self.selections = selections
  }

  public static let off = ShieldPlan(selections: [])
  public var isOff: Bool { selections.isEmpty }
}

public enum DoorSchedulePlan: Hashable, Sendable {
  case start(Door)
  case stop
}
