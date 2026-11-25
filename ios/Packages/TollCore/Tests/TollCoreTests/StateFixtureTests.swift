import Foundation
import Testing

@testable import TollCore

/// Every format the state file has had, as the build of its day wrote it (`Fixtures/state`), reads
/// as the person it held at today's schema and writes back unchanged (#140). The v2 files were made
/// by each past build's own encoder from the same set-up person: Sleep at Home, Study at the
/// library, the night on, an edit held, a pause asked.
struct StateFixtureTests {
  static let past = [
    "v1", "v2-01-blocks", "v2-02-door-app", "v2-03-screen-time", "v2-04-only-at-place",
    "v2-05-pause", "v2-06-cards", "v2-07-heads-up", "v2-08-gap", "v2-09-helpers",
    "v2-10-last-night",
  ]
  /// The current format; a new schema adds its own and moves this one into `past`.
  static let newest = "v3"
  /// A past shape under a newer label: a build from before #140 writes back the `schema` it read,
  /// so after a downgrade its own shape says 3. It has no `minReader`.
  static let relabelled = [
    "relabelled-v2-07": "v2-07-heads-up", "relabelled-v2-10": "v2-10-last-night",
  ]

  static func fixture(_ name: String) throws -> Data {
    let url = try #require(
      Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures/state"))
    return try Data(contentsOf: url)
  }

  @Test func everyFixtureIsListed() throws {
    let folder = try #require(Bundle.module.resourceURL).appending(path: "Fixtures/state")
    let names = try FileManager.default.contentsOfDirectory(atPath: folder.path)
      .filter { $0.hasSuffix(".json") }.map { String($0.dropLast(5)) }
    #expect(Set(names) == Set(Self.past + [Self.newest] + Self.relabelled.keys))
  }

  @Test(arguments: past + [newest])
  func readsAsThePersonItHeldAndRoundTrips(_ name: String) throws {
    let data = try Self.fixture(name)
    let reading = DuskStore.reading(data)
    #expect(reading.lost == 0)
    #expect(reading.writable)
    let state = reading.state
    #expect(state.schema == DuskState.schema)
    let sleep = try #require(state.sleepBlock)
    #expect(sleep.schedule == .everyDay(usual))
    #expect(sleep.apps == Data([1]))
    #expect(sleep.place == PlaceID("home"))
    #expect(state.presence[PlaceID("home")]?.isInside == true)
    #expect(state.setupFinishedAt != nil)
    #expect(state.trial.start == date(2026, 11, 17, 15))
    #expect(state.runtime.active[BlockID("sleep")] != nil)
    #expect(state.door != nil)
    if name != "v1" {
      #expect(state.blocks.map(\.kind) == [.sleep, .study])
      #expect(state.places.count == 2)
      #expect(state.pending.count == 2)
      #expect(state.location == .places)
    }
    if name < "v2-08" {
      // From before D76: the night as it was, and the gap offered once.
      #expect(state.gap.minutes == 0)
      #expect(state.gap.offered)
    } else {
      #expect(state.gap.minutes == 15)
      #expect(state.gap.mode == .grows)
      #expect(!state.gap.offered)
    }
    if name >= "v2-09" { #expect(state.helpers.breathMinutes == 5) }
    if name >= "v2-10" { #expect(state.lastNightSeen == date(2026, 11, 16, 0)) }
    let again = try DuskStore.encoder.encode(state)
    #expect(DuskStore.decode(again) == state)
  }

  /// Read as the shape it is, so every step it needs still runs: the heads-up build's file has no
  /// gap, and is offered it once, as its own v2 label would be.
  @Test(arguments: relabelled.keys.sorted())
  func aPastShapeUnderANewerLabelStillMigrates(_ name: String) throws {
    let reading = DuskStore.reading(try Self.fixture(name))
    let original = DuskStore.reading(
      try Self.fixture(try #require(Self.relabelled[name])))
    #expect(reading.schema == 2)
    #expect(reading.writable)
    #expect(reading.state == original.state)
    #expect(reading.state.gap.offered == (name == "relabelled-v2-07"))
  }

  /// A new field can't land without a fixture: what today's encoder writes must have the newest
  /// fixture's shape. If this fails, raise `DuskState.schema`, add a migration step and its test,
  /// and add the new format as the newest fixture.
  @Test func theNewestFixtureHasTodaysShape() throws {
    let newest = try JSONSerialization.jsonObject(with: try Self.fixture(Self.newest))
    let today = try JSONSerialization.jsonObject(with: try DuskStore.encoder.encode(Self.full()))
    #expect(Self.paths(today) == Self.paths(newest))
    #expect((newest as? [String: Any])?["schema"] as? Int == DuskState.schema)
  }

  /// Every key path a value writes, ids and list positions left out.
  static func paths(_ value: Any, _ prefix: String = "") -> Set<String> {
    if let object = value as? [String: Any] {
      return object.reduce(into: Set<String>()) { result, entry in
        let path = prefix + "." + entry.key
        result.insert(path)
        result.formUnion(paths(entry.value, path))
      }
    }
    if let list = value as? [Any] {
      return list.reduce(into: Set<String>()) { $0.formUnion(paths($1, prefix + "[]")) }
    }
    return []
  }

  /// A state with every field set, as `v3.json` holds it.
  static func full() -> DuskState {
    var state = setUp()
    state.places.append(libraryPlace)
    state.blocks.append(studyBlock())
    state.setupFinishedAt = date(2026, 11, 17, 15)
    state.trial.start = date(2026, 11, 17, 15)
    state.screenTimeAllowed = true
    run(&state, date(2026, 11, 17, 23))
    var edit = sleepBlock(TimeWindow(start: time(23), end: time(7)))
    edit.name = "Night"
    state.pending[edit.id] = .save(edit)
    state.pending[BlockID("study")] = .delete
    var moved = libraryPlace
    moved.radiusMeters = 200
    state.pendingPlaces[moved.id] = moved
    var door = Door(waitEndsAt: date(2026, 11, 17, 23, 1))
    door.openedAt = date(2026, 11, 17, 23, 1)
    door.expiresAt = date(2026, 11, 17, 23, 11)
    state.door = door
    state.doorAskedAt = date(2026, 11, 17, 23)
    state.runtime.scheduledDoor = date(2026, 11, 17, 23, 1)
    state.dismissedCards = ["home"]
    state.gap = .newInstall()
    state.gap.history = [.init(night: date(2026, 11, 17, 0), minutes: 15)]
    state.gap.pending = .grows(30)
    state.gap.change = Gap.Change(week: date(2026, 11, 16, 0), from: 15, to: 30)
    state.gap.frozenThrough = date(2026, 11, 16, 0)
    state.gap.tally = Gap.Tally(week: date(2026, 11, 16, 0))
    state.gap.tally.nights = [date(2026, 11, 16, 0)]
    state.helpers.breathMinutes = 5
    state.lastNightSeen = date(2026, 11, 16, 0)
    state.recoveredAt = date(2026, 11, 17, 9)
    state.flows["example"] = FlowRecord(
      version: 1, outcome: .notNow, at: date(2026, 11, 17, 10), notNow: 1)
    state.writtenBy = "0.9.0 (42)"
    return state
  }
}
