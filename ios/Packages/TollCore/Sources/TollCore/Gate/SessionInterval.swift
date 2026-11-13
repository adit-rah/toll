import Foundation

/// The one-off DeviceActivity interval that wakes the monitor when a session's time is up (G-6).
/// The platform rejects intervals shorter than 15 minutes, so a shorter session gets a 15-minute
/// interval whose end warning lands on the session's own end.
public struct SessionInterval: Equatable, Sendable {
  public static let platformMinimumMinutes = 15

  public var start: Date
  public var end: Date
  /// Minutes before `end` at which the end warning fires; nil when the interval ends with the session.
  public var warningMinutes: Int?

  public init(session: ActiveSession) {
    let length = max(session.minutes, Self.platformMinimumMinutes)
    let lead = length - session.minutes
    start = session.startedAt
    // Interval edges are given to the system in whole seconds. Rounding the end up keeps the warning
    // and the end at or after the persisted expiry; the monitor ends a session only once that has passed.
    let exactEnd = session.startedAt.addingTimeInterval(TimeInterval(length * 60))
    end = Date(timeIntervalSince1970: exactEnd.timeIntervalSince1970.rounded(.up))
    warningMinutes = lead > 0 ? lead : nil
  }
}
