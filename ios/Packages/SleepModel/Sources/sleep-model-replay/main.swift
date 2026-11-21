import Foundation
import SleepModel

// Replays cases through the Swift model and prints one JSON line of steps per case, so the Python side
// can compare and plot the phone's numbers against the reference:
//   swift run sleep-model-replay < fixtures.jsonl > swift-steps.jsonl
// A case is {"name", "artifact", "seed", "allowed", "nights"}; other lines (the rng case) are skipped.

struct Case: Decodable {
  var name: String
  var artifact: ModelArtifact
  var seed: UInt64
  var allowed: [Int]?
  var nights: [NightRecord]
}

struct Output: Encodable {
  var name: String
  var steps: [ReplayStep]
}

let decoder = JSONDecoder()
let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys]
while let line = readLine(strippingNewline: true) {
  guard let data = line.data(using: .utf8), let c = try? decoder.decode(Case.self, from: data)
  else {
    continue
  }
  let steps = Replay.run(artifact: c.artifact, nights: c.nights, seed: c.seed, allowed: c.allowed)
  let out = try encoder.encode(Output(name: c.name, steps: steps))
  print(String(decoding: out, as: UTF8.self))
}
