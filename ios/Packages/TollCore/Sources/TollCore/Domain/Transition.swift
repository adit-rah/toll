import Foundation

/// Why a reconcile ran (B-5, B-6). Raw values are what the log file holds.
public enum ReconcileCause: String, Codable, Sendable, CaseIterable {
  case launch, foreground
  case windowStart, windowEnd, sweepStart, sweepEnd
  /// The monitor's daily wake just after noon; on Monday it judges the week (#127).
  case weekTurn
  case arrived, left
  case edit, entitlement, permission
  /// The block screen's "Never mind": the one tap that counts as being stopped (D24).
  case blockScreen
  /// The block screen's "Unlock in Dusk" (D32); older logs wrote these as `blockScreen` too.
  case doorAsked
  case doorChosen, doorCancelled, doorLocked, doorStart, doorEnd
  /// A helper before bed was opened (D80): the night record's private `helper` reads these.
  case helperList, helperBreathe, helperWords
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
  /// The door after this reconcile, nil when there is none.
  public var door: Door.Phase?
  /// The blocks on after this reconcile; nil in lines written before blocks (D29).
  public var active: [BlockID]?
  /// Screen Time access as the app last read it; false means nothing could block, whatever `active`
  /// says. Nil in older lines and before the app has read it (#60).
  public var screenTime: Bool?

  public init(
    at: Date, cause: ReconcileCause, blockOn: Bool, changed: Bool, home: Bool?, inWindow: Bool,
    entitled: Bool, door: Door.Phase? = nil, active: [BlockID]? = nil, screenTime: Bool? = nil
  ) {
    self.at = at
    self.cause = cause
    self.blockOn = blockOn
    self.changed = changed
    self.home = home
    self.inWindow = inWindow
    self.entitled = entitled
    self.door = door
    self.active = active
    self.screenTime = screenTime
  }
}
