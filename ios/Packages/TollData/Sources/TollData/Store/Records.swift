import Foundation
import GRDB
import TollCore

struct EventRow: Codable, FetchableRecord, PersistableRecord, Sendable {
  static let databaseTableName = "event"

  var id: String
  var kind: String
  var occurredAt: Double
  var tzOffset: Int
  var appRef: String?
  var blockRef: String?
  var appRefs: [AppRef]?
  var via: String?
  var free: Bool?
  var waitMinutes: Int?
  var sessionMinutes: Int?
  var schedule: Schedule?
  var oldSchedule: Schedule?
  var uploadedAt: Double?

  init(_ e: GateEvent) {
    id = e.id.lowercasedString
    kind = e.kind.rawValue
    occurredAt = e.occurredAt.timeIntervalSince1970
    tzOffset = e.tzOffsetMinutes
    appRef = e.appRef?.rawValue
    blockRef = e.blockRef?.rawValue
    appRefs = e.appRefs
    via = e.via?.rawValue
    free = e.free
    waitMinutes = e.waitMinutes
    sessionMinutes = e.sessionMinutes
    schedule = e.schedule
    oldSchedule = e.oldSchedule
  }

  var event: GateEvent? {
    guard let uuid = UUID(uuidString: id), let kind = GateEvent.Kind(rawValue: kind) else {
      return nil
    }
    return GateEvent(
      id: uuid, kind: kind, occurredAt: Date(timeIntervalSince1970: occurredAt),
      tzOffsetMinutes: tzOffset,
      appRef: appRef.map(AppRef.init(rawValue:)), blockRef: blockRef.map(BlockRef.init(rawValue:)),
      appRefs: appRefs, via: via.flatMap(GateEvent.Via.init(rawValue:)), free: free,
      waitMinutes: waitMinutes,
      sessionMinutes: sessionMinutes, schedule: schedule, oldSchedule: oldSchedule)
  }
}

/// A block as the app keeps it: the extension-facing definition plus the name only this user sees.
public struct StoredBlock: Codable, Hashable, Sendable, Identifiable, FetchableRecord,
  PersistableRecord
{
  public static let databaseTableName = "block"

  public var id: BlockRef
  public var name: String?
  public var schedule: Schedule
  public var appRefs: [AppRef]
  public var createdAt: Date

  public init(id: BlockRef, name: String?, schedule: Schedule, appRefs: [AppRef], createdAt: Date) {
    self.id = id
    self.name = name
    self.schedule = schedule
    self.appRefs = appRefs
    self.createdAt = createdAt
  }

  public var definition: BlockDefinition {
    BlockDefinition(id: id, appRefs: appRefs, schedule: schedule)
  }
}

public struct StoredApp: Codable, Hashable, Sendable, FetchableRecord, PersistableRecord {
  public static let databaseTableName = "app"

  public var appRef: AppRef
  public var tag: Tag?
  public var kind: TokenKind

  public init(appRef: AppRef, tag: Tag?, kind: TokenKind) {
    self.appRef = appRef
    self.tag = tag
    self.kind = kind
  }
}

struct SettingRow: Codable, FetchableRecord, PersistableRecord {
  static let databaseTableName = "setting"
  var key: String
  var value: Data
}

struct TollOpenRow: Codable, FetchableRecord, PersistableRecord {
  static let databaseTableName = "tollOpen"
  var day: String
  var count: Int
}

struct PendingWriteRow: Codable, FetchableRecord, MutablePersistableRecord, Sendable {
  static let databaseTableName = "pendingWrite"
  var id: Int64?
  var method: String
  var path: String
  var body: Data?
  var idempotencyKey: String
  var createdAt: Double

  mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
}

extension AppRef: @retroactive DatabaseValueConvertible {}
extension BlockRef: @retroactive DatabaseValueConvertible {}
extension Tag: @retroactive DatabaseValueConvertible {}
extension TokenKind: @retroactive DatabaseValueConvertible {}
