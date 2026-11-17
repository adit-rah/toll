import Foundation

/// Why a reconcile ran (B-5, B-6). Raw values are what the log file holds.
public enum ReconcileCause: String, Codable, Sendable, CaseIterable {
  case launch, foreground
  case windowStart, windowEnd, sweepStart, sweepEnd
  case arrived, left
  case edit, blockScreen, entitlement
}

/// One line of the transition log (B-6): when, why, and the state that resulted.
public struct Transition: Codable, Hashable, Sendable {
  public var at: Date
  public var cause: ReconcileCause
  public var blockOn: Bool
  /// False when a wake left the block as it was; kept so missed and late callbacks show in the log.
  public var changed: Bool
  public var home: Bool?
  public var inWindow: Bool
  public var entitled: Bool

  public init(
    at: Date, cause: ReconcileCause, blockOn: Bool, changed: Bool, home: Bool?, inWindow: Bool,
    entitled: Bool
  ) {
    self.at = at
    self.cause = cause
    self.blockOn = blockOn
    self.changed = changed
    self.home = home
    self.inWindow = inWindow
    self.entitled = entitled
  }
}
