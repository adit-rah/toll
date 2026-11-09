import Foundation

/// A fact recorded on the device (spec §4). The server resolves tags by app ref, so events never carry one.
public struct GateEvent: Codable, Hashable, Sendable, Identifiable {
  public enum Kind: String, Codable, Sendable, CaseIterable {
    case blockHit = "block_hit"
    case waitStarted = "wait_started"
    case waitCompleted = "wait_completed"
    case waitAbandoned = "wait_abandoned"
    case pass
    case sessionEnded = "session_ended"
    case blockAdded = "block_added"
    case blockChanged = "block_changed"
    case blockRemoved = "block_removed"
    case checkin
  }

  /// How a block hit left the shield. Dismissals count as hits so "walked away" can be measured (ledger A28).
  public enum Via: String, Codable, Sendable {
    case open, dismiss
  }

  public var id: UUID
  public var kind: Kind
  public var occurredAt: Date
  public var tzOffsetMinutes: Int
  public var appRef: AppRef?
  public var blockRef: BlockRef?
  public var appRefs: [AppRef]?
  public var via: Via?
  public var free: Bool?
  public var waitMinutes: Int?
  public var sessionMinutes: Int?
  public var schedule: Schedule?
  public var oldSchedule: Schedule?

  public init(
    id: UUID = .v7(), kind: Kind, occurredAt: Date, tzOffsetMinutes: Int, appRef: AppRef? = nil,
    blockRef: BlockRef? = nil, appRefs: [AppRef]? = nil, via: Via? = nil, free: Bool? = nil,
    waitMinutes: Int? = nil, sessionMinutes: Int? = nil, schedule: Schedule? = nil,
    oldSchedule: Schedule? = nil
  ) {
    self.id = id
    self.kind = kind
    self.occurredAt = occurredAt
    self.tzOffsetMinutes = tzOffsetMinutes
    self.appRef = appRef
    self.blockRef = blockRef
    self.appRefs = appRefs
    self.via = via
    self.free = free
    self.waitMinutes = waitMinutes
    self.sessionMinutes = sessionMinutes
    self.schedule = schedule
    self.oldSchedule = oldSchedule
  }

  public static func offsetMinutes(at date: Date, in timeZone: TimeZone) -> Int {
    timeZone.secondsFromGMT(for: date) / 60
  }
}
