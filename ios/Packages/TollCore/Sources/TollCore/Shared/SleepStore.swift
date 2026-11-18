import Foundation

/// The shared state file. A file under coordination rather than App Group defaults: the app and three
/// extensions write it, and defaults caches per process (decisions D11).
public struct SleepStore: Sendable {
  public let url: URL

  public init(url: URL = AppGroup.file("state.json")) {
    self.url = url
  }

  public func load() -> SleepState {
    CoordinatedFile.read(url).flatMap { try? Self.decoder.decode(SleepState.self, from: $0) }
      ?? SleepState()
  }

  /// Read, change and write as one step, so two processes never interleave.
  @discardableResult
  public func update<T>(_ body: (inout SleepState) -> T) -> T {
    var result: T?
    CoordinatedFile.update(url) { data in
      var state =
        data.flatMap { try? Self.decoder.decode(SleepState.self, from: $0) } ?? SleepState()
      result = body(&state)
      return try? Self.encoder.encode(state)
    }
    if let result { return result }
    // Coordination refused the file: the caller still gets an answer, and nothing is saved.
    var state = load()
    return body(&state)
  }

  static var encoder: JSONEncoder {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = .sortedKeys
    return encoder
  }

  static var decoder: JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }
}
