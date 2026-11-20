import Foundation
import Testing

@testable import SleepModel

struct ArtifactTests {
  @Test func shippedArtifactDecodesAndMatchesBuiltIn() throws {
    let shipped = ModelArtifact.bundled()
    #expect(shipped.version == "sleep-model.v0")
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
    a.schema = 2
    #expect(throws: ModelArtifact.Invalid.schema(2)) { try a.validate() }
    #expect(throws: (any Error).self) { try ModelArtifact.decode(Data("{}".utf8)) }
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

  @Test func localTimesParse() throws {
    let a = try #require(LocalTime("2026-01-05T23:00:00-05:00"))
    let b = try #require(LocalTime("2026-01-06T04:30:00.250000Z"))
    #expect(b.minutes(since: a) == 30.0 + 0.25 / 60)
    #expect(LocalTime("2026-01-05 23:00") == nil)
    #expect(
      LocalTime("2026-01-05T23:00:00+05:30")?.micros == LocalTime("2026-01-05T17:30:00Z")?.micros)
  }
}
