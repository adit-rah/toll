import Foundation

/// What the application layer needs from outside (docs/architecture.md). Adapters implement these:
/// the App Group file, ManagedSettings, DeviceActivity, the transition log. Tests use fakes.
public protocol StatePort: Sendable {
  func load() -> DuskState
  /// Read, change and write as one step, so two processes never interleave. `body` is told first
  /// whether its change will be saved. Nil when the state couldn't be read at all, such as before
  /// the first unlock after a restart: `body` didn't run.
  func update<T>(_ body: (inout DuskState, StateAccess) -> T) -> Stored<T>?
}

extension StatePort {
  func update<T>(_ body: (inout DuskState) -> T) -> Stored<T>? {
    update { state, _ in body(&state) }
  }
}

/// What `StatePort.update` did with the change.
public enum StateAccess: Sendable, Equatable {
  case saved
  /// Read but not written: a newer build's file this one mustn't write (`DuskState.minReader`),
  /// or one that couldn't be kept aside first.
  case readOnly
}

public struct Stored<T> {
  public var value: T
  public var access: StateAccess
}

extension Stored: Sendable where T: Sendable {}

public protocol ShieldPort: Sendable {
  func apply(_ plan: ShieldPlan)
}

public protocol SchedulePort: Sendable {
  /// Replaces every window schedule with these (and a sweep after each).
  func monitor(windows: [TimeWindow]) throws
  func startDoor(_ door: Door, config: TollConfig) throws
  func stopDoor()
}

public protocol LogPort: Sendable {
  func append(_ line: Transition)
}
