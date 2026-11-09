import Foundation
import Testing

@testable import TollCore

struct SpoolTests {
  let at = Date(timeIntervalSince1970: 1_800_000_000)

  func record(_ app: AppRef) -> SpoolRecord {
    SpoolRecord(kind: .blockHit, at: at, tzOffsetMinutes: -300, appRef: app, via: .open)
  }

  @Test func roundTripsCompleteLines() throws {
    var data = Data()
    for app: AppRef in ["a", "b"] { data.append(try #require(SpoolCodec.line(for: record(app)))) }
    let parsed = SpoolCodec.parse(data)
    #expect(parsed.records.map(\.appRef) == ["a", "b"])
    #expect(parsed.remainder.isEmpty && parsed.skipped == 0)
    #expect(parsed.records[0].at == at)
  }

  @Test func keepsAnUnterminatedTailForTheNextIngest() throws {
    var data = try #require(SpoolCodec.line(for: record("a")))
    let partial = try #require(SpoolCodec.line(for: record("b"))).prefix(20)
    data.append(partial)
    let parsed = SpoolCodec.parse(data)
    #expect(parsed.records.count == 1)
    #expect(parsed.remainder == partial)
  }

  @Test func skipsGarbledCompleteLinesAndBlankOnes() throws {
    var data = Data("{\"id\":\"trunc\n\n".utf8)
    data.append(try #require(SpoolCodec.line(for: record("a"))))
    let parsed = SpoolCodec.parse(data)
    #expect(parsed.records.count == 1)
    #expect(parsed.skipped == 1)
  }

  @Test func appendAndDrainThroughTheFile() throws {
    let url = FileManager.default.temporaryDirectory.appending(
      path: "spool-\(UUID().uuidString).jsonl")
    defer { try? FileManager.default.removeItem(at: url) }
    let spool = Spool(url: url)
    spool.append(record("a"))
    spool.append(record("b"))
    #expect(spool.drain().records.count == 2)
    #expect(spool.drain().records.isEmpty)
    spool.append(record("c"))
    #expect(spool.drain().records.map(\.appRef) == ["c"])
  }

  @Test func sharedStateSurvivesConcurrentStyleUpdates() throws {
    let url = FileManager.default.temporaryDirectory.appending(
      path: "state-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: url) }
    let store = SharedGateStore(url: url)
    store.update {
      $0.unblocks = ["a": 2]
      $0.unblocksDay = TollDay(year: 2026, month: 11, day: 9)
    }
    store.update { $0.notificationsAllowed = true }
    let state = store.load()
    #expect(state.notificationsAllowed)
    #expect(state.unblocks(of: "a", on: TollDay(year: 2026, month: 11, day: 9)) == 2)
    #expect(state.unblocks(of: "a", on: TollDay(year: 2026, month: 11, day: 10)) == 0)
  }
}
