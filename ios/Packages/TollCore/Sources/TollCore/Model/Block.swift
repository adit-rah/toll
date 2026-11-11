import Foundation

/// What the extensions need to know about a block: which app refs it shields and when. The block name
/// and the tokens themselves stay in the app (names in the store, tokens in `TokenRegistry`).
public struct BlockDefinition: Codable, Hashable, Sendable, Identifiable {
  public var id: BlockRef
  public var appRefs: [AppRef]
  public var schedule: Schedule

  public init(id: BlockRef, appRefs: [AppRef], schedule: Schedule) {
    self.id = id
    self.appRefs = appRefs
    self.schedule = schedule
  }

  /// The DeviceActivity name for this block's schedule window.
  public var activityName: String { "block.\(id.rawValue)" }
}

/// A session after a pass (G-6): the unlocked apps and the minutes chosen. It runs on the wall clock
/// from `startedAt`; the persisted expiry is the truth when callbacks are late or missing.
public struct ActiveSession: Codable, Hashable, Sendable, Identifiable {
  /// For callers with no remote config to hand (the monitor): the spec §14 default.
  public static let defaultTolerance = TimeInterval(TollConfig.Gate().clockSkewToleranceSeconds)

  public var id: UUID
  public var appRefs: [AppRef]
  public var minutes: Int
  public var startedAt: Date
  public var expiresAt: Date
  public var blockRef: BlockRef?
  /// Absent in state written before sessions were guarded against clock changes (G-9).
  public var startedMonotonic: MonotonicInstant?

  public init(
    id: UUID = UUID(), appRefs: [AppRef], minutes: Int, startedAt: Date, blockRef: BlockRef? = nil,
    startedMonotonic: MonotonicInstant? = nil
  ) {
    self.id = id
    self.appRefs = appRefs
    self.minutes = minutes
    self.startedAt = startedAt
    expiresAt = startedAt.addingTimeInterval(TimeInterval(minutes * 60))
    self.blockRef = blockRef
    self.startedMonotonic = startedMonotonic
  }

  public var activityName: String { "session.\(id.uuidString.lowercased())" }

  /// G-9, as `Wait.elapsed`: within one boot, the monotonic clock is heard whenever the wall clock
  /// disagrees by more than the tolerance, so setting the clock back cannot lengthen a session.
  /// Unlike a wait, the earlier end wins: the monitor's wake is a wall-clock interval, and a session
  /// that outlived it after the clock went forward would have nothing left to end it.
  /// Across a reboot, or with no monotonic reading, only the persisted wall-clock expiry is left.
  public func remaining(
    at date: Date, monotonic: MonotonicInstant? = nil,
    tolerance: TimeInterval = ActiveSession.defaultTolerance
  ) -> TimeInterval {
    let wall = expiresAt.timeIntervalSince(date)
    guard let start = startedMonotonic, let current = monotonic, start.bootID == current.bootID
    else {
      return wall
    }
    let steady = expiresAt.timeIntervalSince(startedAt) - (current.seconds - start.seconds)
    return abs(wall - steady) > tolerance ? min(wall, steady) : wall
  }

  public func isExpired(
    at date: Date, monotonic: MonotonicInstant? = nil,
    tolerance: TimeInterval = ActiveSession.defaultTolerance
  ) -> Bool {
    remaining(at: date, monotonic: monotonic, tolerance: tolerance) <= 0
  }

  /// Whole minutes left, rounded up, so the line reads "1 min left" until the session is over.
  public func minutesLeft(
    at date: Date, monotonic: MonotonicInstant? = nil,
    tolerance: TimeInterval = ActiveSession.defaultTolerance
  ) -> Int {
    max(0, Int((remaining(at: date, monotonic: monotonic, tolerance: tolerance) / 60).rounded(.up)))
  }
}
