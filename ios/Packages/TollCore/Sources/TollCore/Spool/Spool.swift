import Foundation

/// The App Group spool file: extensions append, the app drains (spec §11.1).
public struct Spool: Sendable {
  public let url: URL

  public init(url: URL = AppGroup.file("spool.jsonl")) {
    self.url = url
  }

  public func append(_ record: SpoolRecord) {
    guard let line = SpoolCodec.line(for: record) else { return }
    CoordinatedFile.append(line, to: url)
  }

  /// Returns every complete record and leaves only an unterminated tail in the file.
  public func drain() -> SpoolCodec.Parsed {
    var parsed = SpoolCodec.Parsed(records: [], remainder: Data(), skipped: 0)
    CoordinatedFile.update(url) { data in
      guard let data, !data.isEmpty else { return nil }
      parsed = SpoolCodec.parse(data)
      return parsed.remainder
    }
    return parsed
  }
}
