import Foundation
import Testing

@testable import SleepModel

/// The rebuild from a night log (#140) against the Python reference (`export/rebuild.py`): every
/// past shape of the record, duplicates and corrections, the highest revision of each night, in
/// night order. Then the cache: moved on night by night, it equals a rebuild; anything that changes
/// a night it saw, or a new artifact, rebuilds it.
struct RebuildTests {
  struct Fixture {
    var artifact: ModelArtifact
    var lines: [Data]
    var state: PersonState
    var hold: Hold?
  }

  static func fixture() throws -> Fixture {
    let url = try #require(
      Bundle.module.url(forResource: "rebuild", withExtension: "json", subdirectory: "Fixtures"))
    let json = try #require(
      try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    let artifact = try ModelArtifact.decode(
      JSONSerialization.data(withJSONObject: try #require(json["artifact"])))
    let lines = try #require(json["lines"] as? [[String: Any]]).map {
      try JSONSerialization.data(withJSONObject: $0)
    }
    let state = try JSONDecoder().decode(
      PersonState.self, from: JSONSerialization.data(withJSONObject: try #require(json["state"])))
    let hold = try (json["hold"] as? [String: Any]).map {
      try JSONDecoder().decode(Hold.self, from: JSONSerialization.data(withJSONObject: $0))
    }
    return Fixture(artifact: artifact, lines: lines, state: state, hold: hold)
  }

  /// sleep-model.v0, as the parity fixtures carry it: what every cache on a phone was built with.
  static func v0() throws -> ModelArtifact {
    try #require(try ParityTests.cases().first { $0.name == "v0-artifact" }).artifact
  }

  static func same(_ a: PersonState, _ b: PersonState) -> Bool {
    a.nights == b.nights && a.shown == b.shown
      && zip(a.precision + a.b, b.precision + b.b).allSatisfy { ParityTests.close($0, $1) }
  }

  @Test func aRebuildMatchesPython() throws {
    let f = try Self.fixture()
    let records = ModelCache.current(f.lines)
    #expect(records.map(\.night) == records.map(\.night).sorted())
    #expect(Set(records.map(\.night)).count == records.count)
    let rebuilt = ModelCache.refreshed(nil, artifact: f.artifact, policy: "fixed", records: records)
    #expect(rebuilt.rebuilt)
    #expect(Self.same(rebuilt.cache.state, f.state))
  }

  @Test func movedOnNightByNightItEqualsARebuild() throws {
    let f = try Self.fixture()
    let records = ModelCache.current(f.lines)
    var cache: ModelCache?
    for count in [5, 12, 20, records.count] {
      let step = ModelCache.refreshed(
        cache, artifact: f.artifact, policy: "fixed", records: Array(records.prefix(count)))
      #expect(step.rebuilt == (cache == nil))
      cache = step.cache
    }
    #expect(cache?.state == SleepModel(artifact: f.artifact, nights: records).state)
  }

  @Test func aCorrectionToANightItSawRebuildsIt() throws {
    let f = try Self.fixture()
    let records = ModelCache.current(f.lines)
    let cache = ModelCache.refreshed(nil, artifact: f.artifact, policy: "fixed", records: records)
    var corrected = records
    corrected[2].rev = corrected[2].revision + 1
    corrected[2].sleepOnset = corrected[2].bedtime
    let after = ModelCache.refreshed(
      cache.cache, artifact: f.artifact, policy: "fixed", records: corrected)
    #expect(after.rebuilt)
    #expect(after.cache.state == SleepModel(artifact: f.artifact, nights: corrected).state)
  }

  @Test func aNewArtifactRebuildsIt() throws {
    let f = try Self.fixture()
    let records = ModelCache.current(f.lines)
    let cache = ModelCache.refreshed(nil, artifact: f.artifact, policy: "fixed", records: records)
    var next = f.artifact
    next.version = "sleep-model.v2"
    next.forgetting = 0.97
    let after = ModelCache.refreshed(cache.cache, artifact: next, policy: "fixed", records: records)
    #expect(after.rebuilt)
    #expect(after.cache.artifact.version == "sleep-model.v2")
    #expect(after.cache.state == SleepModel(artifact: next, nights: records).state)
  }

  /// D92's path for this release: a cache built with sleep-model.v0 is rebuilt from every night
  /// under the artifact this package ships, and comes out as Python's rebuild.
  @Test func aV0CacheIsRebuiltUnderTheShippedArtifact() throws {
    let f = try Self.fixture()
    let v0 = try Self.v0()
    #expect(v0.version == "sleep-model.v0" && v0.schema == 1)
    var shipped = ModelArtifact.bundled()
    shipped.sha256 = f.artifact.sha256
    #expect(shipped == f.artifact)
    let records = ModelCache.current(f.lines)
    let old = ModelCache.refreshed(nil, artifact: v0, policy: "fixed", records: records)
    let after = ModelCache.refreshed(
      old.cache, artifact: ModelArtifact.bundled(), policy: "fixed", records: records)
    #expect(after.rebuilt)
    #expect(after.cache.artifact.version == "sleep-model.v1")
    #expect(Self.same(after.cache.state, f.state))
  }

  /// After a rebuild the week's start stays where the night log says it is.
  @Test func theHoldComesBackFromTheLog() throws {
    let f = try Self.fixture()
    let records = ModelCache.current(f.lines)
    let hold = try #require(f.hold)
    #expect(Hold.latest(in: records) == hold)
    let model = SleepModel(artifact: f.artifact, nights: records)
    let last = try #require(records.last)
    var rng = SeededRNG(seed: 1)
    let tonight = model.chooseStart(
      night: last.night, last.context(f.artifact), held: Hold.latest(in: records), rng: &rng)
    #expect(tonight == hold && rng == SeededRNG(seed: 1))
    #expect(records.filter { $0.policy != "held" }.allSatisfy { $0.hold == nil })
  }

  @Test func theCacheRoundTrips() throws {
    let f = try Self.fixture()
    let cache = ModelCache.refreshed(
      nil, artifact: f.artifact, policy: "fixed", records: ModelCache.current(f.lines)
    ).cache
    let again = try JSONDecoder().decode(ModelCache.self, from: JSONEncoder().encode(cache))
    #expect(again == cache)
  }
}
