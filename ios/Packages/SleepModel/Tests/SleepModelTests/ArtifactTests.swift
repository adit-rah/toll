import Foundation
import Testing

@testable import SleepModel

struct ArtifactTests {
  @Test func shippedArtifactDecodesAndMatchesBuiltIn() throws {
    let shipped = ModelArtifact.bundled()
    #expect(shipped.version == "sleep-model.v1")
    #expect(shipped.schema == ModelArtifact.schemaVersion)
    #expect(shipped.sha256?.count == 64)
    var withoutHash = shipped
    withoutHash.sha256 = nil
    var builtIn = ModelArtifact.builtIn
    builtIn.sha256 = nil
    #expect(withoutHash == builtIn)
  }

  @Test func invalidArtifactIsRefused() throws {
    var a = ModelArtifact.builtIn
    a.actions = [-30, 30]
    #expect(throws: ModelArtifact.Invalid.self) { try a.validate() }
    a = .builtIn
    a.schema = 3
    #expect(throws: ModelArtifact.Invalid.schema(3)) { try a.validate() }
    #expect(throws: (any Error).self) { try ModelArtifact.decode(Data("{}".utf8)) }
    a = .builtIn
    a.policy.holdNights = nil
    #expect(throws: ModelArtifact.Invalid.self) { try a.validate() }
    a = .builtIn
    a.policy.settledExploreShare = 1.5
    #expect(throws: ModelArtifact.Invalid.self) { try a.validate() }
  }

  /// sleep-model.v0's artifact (schema 1) still reads, as v0 behaved: a start every night, never
  /// settled, one zero test.
  @Test func aSchemaOneArtifactReadsAsV0() throws {
    var a = ModelArtifact.builtIn
    a.schema = 1
    a.policy = .init(minProb: 0.1, probDraws: 1000)
    a.insight = .init(interval: 0.9, zeroTestInterval: 0.98, maxWidthMin: 30, minNights: 14)
    try a.validate()
    #expect(a.policy.hold == 1 && !a.policy.settles)
    #expect(a.insight.zeroTestLevel(nights: 500) == 0.98)
    #expect(ModelArtifact.builtIn.insight.zeroTestLevel(nights: 30) == 0.98)
    #expect(ModelArtifact.builtIn.insight.zeroTestLevel(nights: 160) > 0.997)
  }

  @Test func onlyAllowedStartsAreChosen() {
    var model = SleepModel(artifact: .builtIn)
    var rng = SeededRNG(seed: 1)
    for seed in 0..<200 {
      rng = SeededRNG(seed: UInt64(seed))
      let never = model.chooseOffset(NightContext(allowedOffsets: [-30, 0]), rng: &rng)
      #expect(never.offset != 30 && never.prob >= 0.1)
      let only = model.chooseOffset(NightContext(allowedOffsets: [0]), rng: &rng)
      #expect(only.offset == 0 && only.prob == 1.0)
    }
    model = SleepModel(artifact: .builtIn, nights: [])
    #expect(model.state.nights == 0)
  }

  /// D66: one draw a week, Monday to Sunday; a new draw the next Monday, or when the held start
  /// stops being allowed.
  @Test func aStartIsHeldForItsWeek() {
    let model = SleepModel(artifact: .builtIn)
    var rng = SeededRNG(seed: 9)
    let monday = model.chooseStart(night: "2026-11-23", NightContext(), held: nil, rng: &rng)
    #expect(monday.start == "2026-11-23" && !monday.settled)
    let drawn = rng
    for night in ["2026-11-24", "2026-11-27", "2026-11-29"] {
      #expect(model.chooseStart(night: night, NightContext(), held: monday, rng: &rng) == monday)
    }
    #expect(rng == drawn)
    let next = model.chooseStart(night: "2026-11-30", NightContext(), held: monday, rng: &rng)
    #expect(next.start == "2026-11-30" && rng != drawn)
    let other = [-30, 0, 30].filter { $0 != next.offset }
    let limited = model.chooseStart(
      night: "2026-12-02", NightContext(allowedOffsets: other), held: next, rng: &rng)
    #expect(limited.start == "2026-12-02" && other.contains(limited.offset))
    #expect(
      Day.number("2001-01-01") == 0 && Day.period(-1, 7) == -1 && Day.number("2026-1-5") == nil)
  }

  @Test func localTimesParse() throws {
    let a = try #require(LocalTime("2026-01-05T23:00:00-05:00"))
    let b = try #require(LocalTime("2026-01-06T04:30:00.250000Z"))
    #expect(b.minutes(since: a) == 30.0 + 0.25 / 60)
    #expect(LocalTime("2026-01-05 23:00") == nil)
    #expect(
      LocalTime("2026-01-05T23:00:00+05:30")?.micros == LocalTime("2026-01-05T17:30:00Z")?.micros)
  }
}
