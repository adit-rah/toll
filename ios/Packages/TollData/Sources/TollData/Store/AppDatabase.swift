import Foundation
import GRDB

/// The app's SQLite database (spec §11.1). It lives in the app's own container, never the App Group:
/// a database shared with extensions risks 0xdead10cc suspension kills. Migrations are append-only.
public struct AppDatabase: Sendable {
  public let writer: any DatabaseWriter

  public init(_ writer: any DatabaseWriter) throws {
    self.writer = writer
    try Self.migrator.migrate(writer)
  }

  public static func live() throws -> AppDatabase {
    let folder = try FileManager.default.url(
      for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    let pool = try DatabasePool(path: folder.appending(path: "toll.sqlite").path)
    return try AppDatabase(pool)
  }

  public static func inMemory() throws -> AppDatabase {
    try AppDatabase(DatabaseQueue())
  }

  static var migrator: DatabaseMigrator {
    var migrator = DatabaseMigrator()
    migrator.registerMigration("v1") { db in
      try db.create(table: "event") { t in
        t.primaryKey("id", .text)
        t.column("kind", .text).notNull()
        t.column("occurredAt", .double).notNull().indexed()
        t.column("tzOffset", .integer).notNull()
        t.column("appRef", .text)
        t.column("blockRef", .text)
        t.column("appRefs", .jsonText)
        t.column("via", .text)
        t.column("free", .boolean)
        t.column("waitMinutes", .integer)
        t.column("sessionMinutes", .integer)
        t.column("schedule", .jsonText)
        t.column("oldSchedule", .jsonText)
        t.column("uploadedAt", .double).indexed()
      }
      try db.create(table: "block") { t in
        t.primaryKey("id", .text)
        t.column("name", .text)
        t.column("schedule", .jsonText).notNull()
        t.column("appRefs", .jsonText).notNull()
        t.column("createdAt", .datetime).notNull()
      }
      try db.create(table: "app") { t in
        t.primaryKey("appRef", .text)
        t.column("tag", .text)
        t.column("kind", .text).notNull()
      }
      try db.create(table: "setting") { t in
        t.primaryKey("key", .text)
        t.column("value", .jsonText).notNull()
      }
      try db.create(table: "tollOpen") { t in
        t.primaryKey("day", .text)
        t.column("count", .integer).notNull()
      }
      try db.create(table: "pendingWrite") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("method", .text).notNull()
        t.column("path", .text).notNull()
        t.column("body", .blob)
        t.column("idempotencyKey", .text).notNull()
        t.column("createdAt", .double).notNull()
      }
      try db.create(table: "examWeek") { t in
        t.primaryKey("week", .text)
      }
    }
    return migrator
  }
}
