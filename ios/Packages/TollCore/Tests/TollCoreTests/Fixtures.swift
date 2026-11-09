import Foundation
import Testing

/// Loads a JSON file from the repo's `fixtures/` folder, shared with the Worker's tests.
enum Fixtures {
  static let root = URL(filePath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .appending(path: "fixtures")

  static func load<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
    try JSONDecoder().decode(T.self, from: Data(contentsOf: root.appending(path: name)))
  }

  static func instant(_ text: String) -> Date {
    ISO8601DateFormatter().date(from: text) ?? .distantPast
  }
}

struct FixtureFile<Input: Decodable & Sendable, Expected: Decodable & Sendable>: Decodable, Sendable
{
  struct Case: Decodable, Sendable, CustomTestStringConvertible {
    let name: String
    let input: Input
    let expected: Expected
    var testDescription: String { name }
  }
  let cases: [Case]
}
