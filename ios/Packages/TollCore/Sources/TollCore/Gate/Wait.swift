import Foundation

/// The timed cost (G-4). Fixed at start; runs whether or not Toll is open; nothing shortens it.
public struct Wait: Codable, Hashable, Sendable, Identifiable {
  public var id: UUID
  /// The first app is the one named on the card; later hits that joined the wait follow (G-5).
  public var appRefs: [AppRef]
  public var number: Int
  public var minutes: Int
  public var startedAt: Date
  public var startedMonotonic: MonotonicInstant?

  public init(
    id: UUID = UUID(), appRef: AppRef, number: Int, minutes: Int, startedAt: Date,
    startedMonotonic: MonotonicInstant?
  ) {
    self.id = id
    appRefs = [appRef]
    self.number = number
    self.minutes = minutes
    self.startedAt = startedAt
    self.startedMonotonic = startedMonotonic
  }

  public var duration: TimeInterval { TimeInterval(minutes * 60) }

  public var primaryApp: AppRef? { appRefs.first }

  public mutating func join(_ appRef: AppRef) {
    if !appRefs.contains(appRef) { appRefs.append(appRef) }
  }

  /// G-9: within one boot, the monotonic clock wins whenever the wall clock disagrees by more than the
  /// tolerance, so moving the clock either way never shortens a wait. Across a reboot only the wall
  /// clock is left.
  public func elapsed(now: Date, monotonic: MonotonicInstant?, tolerance: TimeInterval)
    -> TimeInterval
  {
    let wall = now.timeIntervalSince(startedAt)
    guard let start = startedMonotonic, let current = monotonic, start.bootID == current.bootID
    else {
      return max(0, wall)
    }
    let steady = current.seconds - start.seconds
    return abs(wall - steady) > tolerance ? max(0, steady) : max(0, wall)
  }

  public func remaining(now: Date, monotonic: MonotonicInstant?, tolerance: TimeInterval)
    -> TimeInterval
  {
    max(0, duration - elapsed(now: now, monotonic: monotonic, tolerance: tolerance))
  }

  public func isComplete(now: Date, monotonic: MonotonicInstant?, tolerance: TimeInterval) -> Bool {
    remaining(now: now, monotonic: monotonic, tolerance: tolerance) <= 0
  }
}
