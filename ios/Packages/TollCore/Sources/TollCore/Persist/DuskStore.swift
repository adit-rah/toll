import Foundation

/// The shared state file (D11): one coordinated JSON file in the App Group, read and written by the
/// app and the extensions. Schema 1 files are migrated on read.
public struct DuskStore: StatePort {
  public let url: URL

  public init(url: URL = AppGroup.file("state.json")) {
    self.url = url
  }

  public func load() -> DuskState {
    CoordinatedFile.read(url).map(Self.decode) ?? DuskState()
  }

  public func update<T>(_ body: (inout DuskState) -> T) -> T {
    var result: T?
    CoordinatedFile.update(url) { data in
      var state = data.map(Self.decode) ?? DuskState()
      result = body(&state)
      return try? Self.encoder.encode(state)
    }
    if let result { return result }
    // Coordination refused the file: the caller still gets an answer, and nothing is saved.
    var state = load()
    return body(&state)
  }

  /// A file that is neither schema 2 nor schema 1 starts over rather than stopping the app.
  static func decode(_ data: Data) -> DuskState {
    let decoder = Self.decoder
    if let state = try? decoder.decode(DuskState.self, from: data), state.schema >= 2 {
      return state
    }
    if let legacy = try? decoder.decode(LegacyStateV1.self, from: data) {
      return Migration.fromV1(legacy)
    }
    return DuskState()
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

extension TransitionLog: LogPort {}
