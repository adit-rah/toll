import Foundation

/// One use of the door (spec §3, D-1 to D-4): one app, a wait, then a few minutes of use.
public struct Door: Codable, Hashable, Sendable {
  public enum Phase: String, Codable, Hashable, Sendable {
    case waiting, open
  }

  /// The chosen app's encoded token. Opaque here: only the Screen Time glue can read it.
  public var app: Data
  public var waitEndsAt: Date
  public var openedAt: Date?
  /// The stored expiry (D-2): when the door's DeviceActivity interval ends, whatever its callbacks did.
  public var expiresAt: Date?
  /// Set by the usage threshold callback; the next reconcile closes the door.
  public var usedUp = false
  /// The previous spend time, put back if the unlock is returned (D-4).
  var spendBefore: Date?

  public var phase: Phase { openedAt == nil ? .waiting : .open }

  public init(app: Data, waitEndsAt: Date) {
    self.app = app
    self.waitEndsAt = waitEndsAt
  }

  /// Within the regret time of opening, "Lock again" returns the unlock (D-4).
  public func regretEndsAt(_ config: TollConfig) -> Date? {
    openedAt?.addingTimeInterval(TimeInterval(config.door.regretSeconds))
  }
}

/// The supply of unlocks (D-5, D-6). Stored as the number spent, so a change to `unlocks.max` in
/// config needs no migration.
public struct UnlockSupply: Codable, Hashable, Sendable {
  public var spent = 0
  /// Consecutive counted nights with no spend.
  public var cleanNights = 0
  /// The last night end already counted.
  public var countedThrough: Date?
  public var lastSpendAt: Date?

  public init() {}

  public func left(_ config: TollConfig) -> Int { max(0, config.unlocks.max - spent) }

  /// Nights still to go before one returns; nil at the maximum.
  public func nightsToRefill(_ config: TollConfig) -> Int? {
    spent > 0 ? max(1, config.unlocks.refillNights - cleanNights) : nil
  }
}
