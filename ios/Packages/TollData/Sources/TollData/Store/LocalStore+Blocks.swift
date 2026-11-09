import Foundation
import GRDB
import TollCore

extension LocalStore {
  public func blocks() throws -> [StoredBlock] {
    try writer.read { db in try StoredBlock.order(Column("createdAt")).fetchAll(db) }
  }

  public nonisolated func observeBlocks() -> AsyncValueObservation<[StoredBlock]> {
    ValueObservation.tracking { db in try StoredBlock.order(Column("createdAt")).fetchAll(db) }
      .values(in: writer)
  }

  public func save(_ block: StoredBlock) throws {
    try writer.write { db in try block.save(db) }
  }

  public func deleteBlock(_ id: BlockRef) throws {
    try writer.write { db in _ = try StoredBlock.deleteOne(db, key: id.rawValue) }
  }

  public func deleteAllBlocks() throws {
    try writer.write { db in _ = try StoredBlock.deleteAll(db) }
  }

  // MARK: Apps and tags

  public func apps() throws -> [StoredApp] {
    try writer.read { db in try StoredApp.fetchAll(db) }
  }

  public nonisolated func observeApps() -> AsyncValueObservation<[StoredApp]> {
    ValueObservation.tracking { db in try StoredApp.fetchAll(db) }.values(in: writer)
  }

  public func tag(for ref: AppRef) throws -> Tag? {
    try writer.read { db in try StoredApp.fetchOne(db, key: ref.rawValue)?.tag }
  }

  /// Adds refs the store has not seen; existing refs keep their tag.
  public func registerApps(_ refs: [AppRef], kinds: [AppRef: TokenKind]) throws {
    try writer.write { db in
      for ref in refs where try StoredApp.fetchOne(db, key: ref.rawValue) == nil {
        try StoredApp(appRef: ref, tag: nil, kind: kinds[ref] ?? .application).insert(db)
      }
    }
  }

  public func setTag(_ tag: Tag, for ref: AppRef) throws {
    try writer.write { db in
      var app =
        try StoredApp.fetchOne(db, key: ref.rawValue)
        ?? StoredApp(appRef: ref, tag: nil, kind: .application)
      app.tag = tag
      try app.save(db)
    }
  }

  // MARK: Exam weeks (I-9)

  public func examWeeks() throws -> Set<TollDay> {
    try writer.read { db in
      Set(try String.fetchAll(db, sql: "SELECT week FROM examWeek").compactMap(TollDay.init))
    }
  }

  public func setExamWeek(_ week: TollDay, marked: Bool) throws {
    try writer.write { db in
      if marked {
        try db.execute(
          sql: "INSERT OR IGNORE INTO examWeek (week) VALUES (?)", arguments: [week.description])
      } else {
        try db.execute(sql: "DELETE FROM examWeek WHERE week = ?", arguments: [week.description])
      }
    }
  }

  // MARK: Pending writes other than events (tags, block meta, exam weeks)

  func enqueueWrite(method: String, path: String, body: Data?, now: Date) throws {
    try writer.write { db in
      var row = PendingWriteRow(
        id: nil, method: method, path: path, body: body, idempotencyKey: UUID.v7().lowercasedString,
        createdAt: now.timeIntervalSince1970)
      try row.insert(db)
    }
  }

  func pendingWrites() throws -> [PendingWriteRow] {
    try writer.read { db in try PendingWriteRow.order(Column("id")).fetchAll(db) }
  }

  func removeWrite(_ id: Int64) throws {
    try writer.write { db in _ = try PendingWriteRow.deleteOne(db, key: id) }
  }
}
