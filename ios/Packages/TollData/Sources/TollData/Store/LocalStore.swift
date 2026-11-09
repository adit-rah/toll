import Foundation
import GRDB
import TollCore

/// Everything the app keeps on the phone: the append-only event log, blocks, tags, settings. Solo mode
/// runs entirely from here (spec §11.4).
public actor LocalStore {
  nonisolated let writer: any DatabaseWriter

  public init(database: AppDatabase) {
    writer = database.writer
  }

  // MARK: Events

  public func record(_ events: [GateEvent]) throws {
    guard !events.isEmpty else { return }
    try writer.write { db in
      for event in events { try EventRow(event).insert(db, onConflict: .ignore) }
    }
  }

  public func events(from start: Date, to end: Date) throws -> [GateEvent] {
    try writer.read { db in
      try EventRow
        .filter(
          Column("occurredAt") >= start.timeIntervalSince1970
            && Column("occurredAt") < end.timeIntervalSince1970
        )
        .order(Column("occurredAt"))
        .fetchAll(db)
        .compactMap(\.event)
    }
  }

  public func allEvents() throws -> [GateEvent] {
    try writer.read { db in
      try EventRow.order(Column("occurredAt")).fetchAll(db).compactMap(\.event)
    }
  }

  public func pendingUpload(limit: Int) throws -> [GateEvent] {
    try writer.read { db in
      try EventRow.filter(Column("uploadedAt") == nil).order(Column("occurredAt")).limit(limit)
        .fetchAll(db)
        .compactMap(\.event)
    }
  }

  public func pendingUploadCount() throws -> Int {
    try writer.read { db in try EventRow.filter(Column("uploadedAt") == nil).fetchCount(db) }
  }

  public func markUploaded(_ ids: Set<String>, at date: Date) throws {
    guard !ids.isEmpty else { return }
    try writer.write { db in
      _ = try EventRow.filter(ids.contains(Column("id")))
        .updateAll(db, Column("uploadedAt").set(to: date.timeIntervalSince1970))
    }
  }

  /// Signing in after solo use uploads history (ledger A2): everything recorded so far becomes pending.
  public func markAllPending() throws {
    try writer.write { db in _ = try EventRow.updateAll(db, Column("uploadedAt").set(to: nil)) }
  }

  /// Live events from a date on, for Home and the gate (spec §11.1 `ValueObservation`).
  public nonisolated func observeEvents(since start: Date) -> AsyncValueObservation<[GateEvent]> {
    ValueObservation.tracking { db in
      try EventRow.filter(Column("occurredAt") >= start.timeIntervalSince1970).order(
        Column("occurredAt")
      )
      .fetchAll(db).compactMap(\.event)
    }
    .values(in: writer)
  }

  // MARK: Toll opens (G-10). Kept on the device only.

  public func incrementTollOpens(day: TollDay) throws -> Int {
    try writer.write { db in
      var row =
        try TollOpenRow.fetchOne(db, key: day.description)
        ?? TollOpenRow(day: day.description, count: 0)
      row.count += 1
      try row.save(db)
      return row.count
    }
  }

  public func tollOpens(day: TollDay) throws -> Int {
    try writer.read { db in try TollOpenRow.fetchOne(db, key: day.description)?.count ?? 0 }
  }

  // MARK: Settings

  public func setting<T: Decodable & Sendable>(_ key: String, as type: T.Type) throws -> T? {
    try writer.read { db in
      guard let row = try SettingRow.fetchOne(db, key: key) else { return nil }
      return try? JSONDecoder().decode(T.self, from: row.value)
    }
  }

  public func setSetting<T: Encodable & Sendable>(_ key: String, _ value: T?) throws {
    try writer.write { db in
      if let value {
        try SettingRow(key: key, value: JSONEncoder().encode(value)).save(db)
      } else {
        _ = try SettingRow.deleteOne(db, key: key)
      }
    }
  }

  // MARK: Wipe

  /// Account deletion and sign-out-with-wipe keep nothing (spec §13).
  public func wipe() throws {
    try writer.write { db in
      for table in ["event", "block", "app", "setting", "tollOpen", "pendingWrite", "examWeek"] {
        try db.execute(sql: "DELETE FROM \(table)")
      }
    }
  }
}
