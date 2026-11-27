import Foundation
import Testing

@testable import SleepModel

/// The Swift model against the Python reference (model spec, section 6.3): every fixture, every night.
/// Numbers within 1e-9 (relative above 1), chosen starts, skips and generator state exactly.
struct ParityTests {
  struct Header: Decodable { var name: String }

  struct Case: Decodable {
    var name: String
    var artifact: ModelArtifact
    var seed: UInt64
    var allowed: [Int]
    var allowedNights: [[Int]]?
    var nights: [NightRecord]
    var steps: [ReplayStep]

    enum CodingKeys: String, CodingKey {
      case name, artifact, seed, allowed, nights, steps
      case allowedNights = "allowed_nights"
    }
  }

  struct RNGCase: Decodable {
    var seed: UInt64
    var u64: [String]
    var uniform: [Double]
    var normal: [Double]
  }

  static let lines: [Data] = {
    guard
      let url = Bundle.module.url(
        forResource: "fixtures", withExtension: "jsonl", subdirectory: "Fixtures"),
      let text = try? String(contentsOf: url, encoding: .utf8)
    else { return [] }
    return text.split(separator: "\n").map { Data($0.utf8) }
  }()

  static func cases() throws -> [Case] {
    try lines.filter { try JSONDecoder().decode(Header.self, from: $0).name != "rng" }
      .map { try JSONDecoder().decode(Case.self, from: $0) }
  }

  static func close(_ a: Double, _ b: Double) -> Bool {
    abs(a - b) <= 1e-9 * max(1, abs(b))
  }

  @Test func fixturesArePresent() throws {
    #expect(try Self.cases().count >= 12)
  }

  @Test func generatorMatches() throws {
    let line = try #require(
      Self.lines.first { (try? JSONDecoder().decode(Header.self, from: $0).name) == "rng" })
    let expected = try JSONDecoder().decode(RNGCase.self, from: line)
    var rng = SeededRNG(seed: expected.seed)
    #expect(expected.u64.map { UInt64($0, radix: 16) } == (0..<8).map { _ in rng.next() })
    for u in expected.uniform { #expect(rng.uniform() == u) }
    for z in expected.normal { #expect(Self.close(rng.normal(), z)) }
  }

  @Test(arguments: try cases())
  func replayMatchesReference(_ c: Case) {
    let steps = Replay.run(
      artifact: c.artifact, nights: c.nights, seed: c.seed, allowed: c.allowed,
      allowedNights: c.allowedNights)
    #expect(steps.count == c.steps.count)
    for (night, (got, want)) in zip(steps, c.steps).enumerated() {
      let at = "\(c.name) night \(night)"
      #expect(got.context == want.context, "\(at) context")
      #expect(got.choice.offset == want.choice.offset, "\(at) chosen start")
      #expect(Self.close(got.choice.prob, want.choice.prob), "\(at) prob")
      #expect(got.choice.holdStart == want.choice.holdStart, "\(at) hold")
      #expect(got.choice.settled == want.choice.settled, "\(at) settled")
      #expect(got.used == want.used && got.skip == want.skip, "\(at) skip")
      #expect(got.rngState == want.rngState, "\(at) generator")
      #expect(got.state.nights == want.state.nights, "\(at) nights")
      #expect(got.state.shown == want.state.shown, "\(at) shown")
      for (g, w) in zip(got.state.precision + got.state.b, want.state.precision + want.state.b) {
        #expect(Self.close(g, w), "\(at) state \(g) vs \(w)")
      }
      for (g, w) in zip(got.predictions, want.predictions) {
        #expect(
          g.offset == w.offset && Self.close(g.mean, w.mean) && Self.close(g.sd, w.sd),
          "\(at) predict")
      }
      #expect(got.insights.count == want.insights.count, "\(at) insights")
      for (g, w) in zip(got.insights, want.insights) {
        #expect(g.kind == w.kind && g.nights == w.nights, "\(at) insight")
        #expect(
          Self.close(g.minutes, w.minutes) && Self.close(g.low, w.low) && Self.close(g.high, w.high)
        )
      }
    }
  }
}

extension ParityTests.Case: CustomTestStringConvertible {
  var testDescription: String { name }
}
