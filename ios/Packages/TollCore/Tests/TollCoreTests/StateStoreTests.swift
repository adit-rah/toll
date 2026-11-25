import Foundation
import Testing

@testable import TollCore

/// #140 risks 1 and 2 at the file: the writer never writes over what it couldn't read, keeps the
/// file as it was before writing over anything it read only in part, and a build older than a
/// file's `minReader` only reads it.
struct StateStoreTests {
  struct Files {
    let folder: URL
    var state: URL { folder.appending(path: "state.json") }
    var nights: NightLog { NightLog(url: folder.appending(path: "nights.jsonl")) }
    var store: DuskStore { DuskStore(url: state, nights: nights) }

    init() {
      folder = FileManager.default.temporaryDirectory.appending(
        path: "store-\(UUID().uuidString)", directoryHint: .isDirectory)
      try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    func kept(_ prefix: String) -> [Data] {
      let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
      return names.filter { $0.hasPrefix(prefix) }.sorted().compactMap {
        try? Data(contentsOf: folder.appending(path: $0))
      }
    }

    func json() throws -> [String: Any] {
      try #require(
        try JSONSerialization.jsonObject(with: Data(contentsOf: state)) as? [String: Any])
    }

    /// Two nights recorded, the later one with new hours and a gap.
    func recordNights() {
      let lines = [
        #"{"night":"2026-11-15","bed":"2026-11-15T23:00:00Z","planned_wake":"2026-11-16T06:30:00Z","gap_min":0}"#,
        #"{"night":"2026-11-16","record":2,"rev":1,"bed":"2026-11-16T22:30:00Z","planned_bedtime":"2026-11-16T22:30:00Z","planned_wake":"2026-11-17T07:00:00Z","gap_min":15}"#,
      ]
      CoordinatedFile.append(Data((lines.joined(separator: "\n") + "\n").utf8), to: nights.url)
    }
  }

  @Test func aFileThatCantBeReadIsKeptAndTheNightComesBack() throws {
    let files = Files()
    files.recordNights()
    let garbage = Data(#"{"schema":3,"blocks":[{"id":"sl"#.utf8)
    try garbage.write(to: files.state)
    let stored = files.store.update { _ in () }
    #expect(stored?.access == .saved)
    #expect(files.kept("state.unreadable-") == [garbage])
    let state = files.store.load()
    let sleep = try #require(state.sleepBlock)
    #expect(sleep.schedule == .everyDay(usual))
    #expect(sleep.apps == nil)
    #expect(state.gap.minutes == 15)
    #expect(state.setupFinishedAt != nil)
    #expect(state.recoveredAt != nil)
    // Read again before any write, it's the same night.
    #expect(sleep.id == Migration.sleepID)
    #expect(files.store.load().sleepBlock?.id == sleep.id)
    #expect(HomeSnapshot(state: state, log: [], now: Date(), calendar: london).recovered)
  }

  /// Tonight's note holds the slot until the night's apps are chosen, held for the night's end
  /// or not.
  @Test func theNoteGoesWhenTheNightsAppsAreChosen() throws {
    var state = setUp()
    state.setupFinishedAt = date(2026, 11, 16, 9)
    state.recoveredAt = date(2026, 11, 17, 9)
    state.blocks[0].apps = nil
    let afternoon = date(2026, 11, 17, 15)
    let home = HomeSnapshot(state: state, log: [], now: afternoon, calendar: london)
    #expect(home.recovered)
    #expect(home.card == nil && !home.lastNightCard)
    var chosen = state
    var night = try #require(chosen.sleepBlock)
    night.apps = Data([1])
    #expect(apply(.saveBlock(night), &chosen, afternoon) == nil)
    #expect(!HomeSnapshot(state: chosen, log: [], now: afternoon, calendar: london).recovered)
    var held = state
    run(&held, date(2026, 11, 17, 23))
    #expect(apply(.saveBlock(night), &held, date(2026, 11, 17, 23)) == nil)
    #expect(held.sleepBlock?.apps == nil)
    #expect(!held.nightNeedsApps)
  }

  @Test func withNoNightRecordItsSetupAgainAndTheFileIsStillKept() {
    let files = Files()
    let garbage = Data("nope".utf8)
    try? garbage.write(to: files.state)
    files.store.update { _ in () }
    #expect(files.kept("state.unreadable-") == [garbage])
    #expect(files.store.load().setupFinishedAt == nil)
  }

  @Test func aSetUpFileThatLostItsNightGetsItBack() throws {
    let files = Files()
    files.recordNights()
    var json = try #require(
      try JSONSerialization.jsonObject(with: StateFixtureTests.fixture("v3")) as? [String: Any])
    var blocks = try #require(json["blocks"] as? [[String: Any]])
    blocks[0]["schedule"] = ["rules": []]
    json["blocks"] = blocks
    try JSONSerialization.data(withJSONObject: json).write(to: files.state)
    let state = files.store.load()
    #expect(state.blocks.map(\.kind) == [.sleep, .study])
    #expect(state.sleepBlock?.schedule == .everyDay(usual))
  }

  /// Before the first unlock after a restart the file is there but closed: nothing runs, nothing
  /// is written, and no effect lifts the shield or stops a schedule.
  @Test func aFileThatCantBeOpenedIsLeftAloneAndNothingHappens() throws {
    let files = Files()
    try FileManager.default.createDirectory(at: files.state, withIntermediateDirectories: true)
    var ran = false
    #expect(files.store.update { _ in ran = true } == nil)
    #expect(files.store.loadIfReadable() == nil)
    #expect(!ran)
    let fakes = CoordinatorTests.Fakes()
    let outcome = Coordinator(store: files.store, shield: fakes, schedule: fakes, log: fakes)
      .run(.sweepStart, clock: CoordinatorTests.FixedClock(now: date(2026, 11, 18, 7, 1)))
    #expect(outcome.access == nil)
    #expect(fakes.shields.isEmpty && fakes.windows.isEmpty && fakes.lines.isEmpty)
  }

  @Test func aFileReadInPartIsKeptOnceBeforeItsWrittenOver() throws {
    let files = Files()
    var json = try #require(
      try JSONSerialization.jsonObject(with: StateFixtureTests.fixture("v3")) as? [String: Any])
    json["location"] = "wifi"
    let partial = try JSONSerialization.data(withJSONObject: json)
    try partial.write(to: files.state)
    files.store.update { _ in () }
    files.store.update { _ in () }
    #expect(files.kept("state.partial-") == [partial])
    #expect(try files.json()["location"] as? String == "scheduleOnly")
  }

  @Test func anOlderFileIsKeptOnceAndWrittenAtTodaysSchema() throws {
    let files = Files()
    let old = try StateFixtureTests.fixture("v2-09-helpers")
    try old.write(to: files.state)
    files.store.update { _ in () }
    files.store.update { _ in () }
    #expect(files.kept("state.v2") == [old])
    let json = try files.json()
    #expect(json["schema"] as? Int == DuskState.schema)
    #expect(json["minReader"] as? Int == DuskState.minReader)
    #expect(json["flows"] is [String: Any])
  }

  /// A newer build's file that this one mustn't write: read, used for the shield, never written,
  /// and its schedules left as that build set them.
  @Test func aFileForNewerReadersIsOnlyRead() throws {
    let files = Files()
    var json = try #require(
      try JSONSerialization.jsonObject(with: StateFixtureTests.fixture("v3")) as? [String: Any])
    json["schema"] = DuskState.schema + 1
    json["minReader"] = DuskState.schema + 1
    json["sleepInterval"] = ["start": "23:00", "end": "07:00"]
    json["runtime"] = [String: Any]()
    json["door"] = nil
    let newer = try JSONSerialization.data(withJSONObject: json, options: .sortedKeys)
    try newer.write(to: files.state)
    let fakes = CoordinatorTests.Fakes()
    let outcome = Coordinator(store: files.store, shield: fakes, schedule: fakes, log: fakes)
      .run(.windowStart, clock: CoordinatorTests.FixedClock(now: date(2026, 11, 17, 23)))
    #expect(outcome.access == .readOnly)
    #expect(try Data(contentsOf: files.state) == newer)
    #expect(fakes.shields.last?.selections == [Data([1])])
    #expect(fakes.windows.isEmpty)
    // A change it can't keep isn't made: the shield stays as the file says, and no line is logged
    // that a night record would read as Screen Time off.
    let refused = Coordinator(store: files.store, shield: fakes, schedule: fakes, log: fakes)
      .run(
        .permission, [.screenTime(false), .headsUp(false)],
        clock: CoordinatorTests.FixedClock(now: date(2026, 11, 17, 23, 5)))
    #expect(refused.error == .readOnly)
    #expect(refused.state.headsUp)
    #expect(refused.state.blocks == outcome.state.blocks)
    #expect(refused.state.screenTimeAllowed == true)
    #expect(fakes.shields.last?.selections == [Data([1])])
    #expect(fakes.lines.isEmpty)
    #expect(try Data(contentsOf: files.state) == newer)
  }

  /// A newer file that allows this build to write it: its new keys are given up by design (the
  /// newer build said so with `minReader`), and the file as it was is kept once.
  @Test func aNewerFileThatAllowsItIsWrittenAtThisSchema() throws {
    let files = Files()
    var json = try #require(
      try JSONSerialization.jsonObject(with: StateFixtureTests.fixture("v3")) as? [String: Any])
    json["schema"] = DuskState.schema + 1
    json["extra"] = true
    let newer = try JSONSerialization.data(withJSONObject: json)
    try newer.write(to: files.state)
    #expect(files.store.update { _ in () }?.access == .saved)
    #expect(files.kept("state.v\(DuskState.schema + 1)") == [newer])
    #expect(try files.json()["schema"] as? Int == DuskState.schema)
  }

  @Test func onlyTheNewestFewCopiesAreKept() throws {
    let files = Files()
    for stamp in 1...5 {
      try Data("nope".utf8).write(
        to: files.folder.appending(path: "state.unreadable-\(stamp).json"))
    }
    try Data("nope".utf8).write(to: files.state)
    files.store.update { _ in () }
    #expect(files.kept("state.unreadable-").count == Kept.keep)
    #expect(
      FileManager.default.fileExists(
        atPath: files.folder.appending(path: "state.unreadable-5.json").path))
  }
}
