import Foundation

/// One line an extension appends to the App Group spool. Extensions cannot use the database
/// (spec §6), so these lines are the only way facts get from an extension to the app.
public struct SpoolRecord: Codable, Hashable, Sendable {
  public enum Kind: String, Codable, Sendable {
    case blockHit = "block_hit"
    case checkin
    case sessionEnded = "session_ended"
  }

  public enum SessionEndReason: String, Codable, Sendable {
    /// No longer written (sessions run on the wall clock); kept so lines from an older build decode.
    case threshold
    case intervalEnd = "interval_end"
    case expiry
  }

  public var id: UUID
  public var kind: Kind
  public var at: Date
  public var tzOffsetMinutes: Int
  public var appRef: AppRef?
  public var appRefs: [AppRef]?
  public var sessionMinutes: Int?
  /// The encoded token when the shield fired for a token the registry did not know (e.g. an app inside a
  /// blocked category). The app resolves it to a new app ref on ingest.
  public var token: Data?
  public var tokenKind: TokenKind?
  public var via: GateEvent.Via?
  public var sessionID: UUID?
  public var reason: SessionEndReason?

  public init(
    id: UUID = .v7(), kind: Kind, at: Date, tzOffsetMinutes: Int, appRef: AppRef? = nil,
    appRefs: [AppRef]? = nil, sessionMinutes: Int? = nil, token: Data? = nil,
    tokenKind: TokenKind? = nil, via: GateEvent.Via? = nil, sessionID: UUID? = nil,
    reason: SessionEndReason? = nil
  ) {
    self.id = id
    self.kind = kind
    self.at = at
    self.tzOffsetMinutes = tzOffsetMinutes
    self.appRef = appRef
    self.appRefs = appRefs
    self.sessionMinutes = sessionMinutes
    self.token = token
    self.tokenKind = tokenKind
    self.via = via
    self.sessionID = sessionID
    self.reason = reason
  }
}

public enum SpoolCodec {
  static let encoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .millisecondsSince1970
    encoder.outputFormatting = [.sortedKeys]
    return encoder
  }()

  static let decoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .millisecondsSince1970
    return decoder
  }()

  public static func line(for record: SpoolRecord) -> Data? {
    guard var data = try? encoder.encode(record) else { return nil }
    data.append(0x0A)
    return data
  }

  public struct Parsed: Equatable, Sendable {
    public var records: [SpoolRecord]
    /// Bytes after the last newline: a line still being written. Kept for the next ingest.
    public var remainder: Data
    public var skipped: Int
  }

  /// Complete lines that fail to decode are dropped and counted; the unterminated tail is kept.
  public static func parse(_ data: Data) -> Parsed {
    var records: [SpoolRecord] = []
    var skipped = 0
    let bytes = [UInt8](data)
    var lineStart = 0
    for (index, byte) in bytes.enumerated() where byte == 0x0A {
      let line = Data(bytes[lineStart..<index])
      lineStart = index + 1
      if line.allSatisfy({ $0 == 0x20 || $0 == 0x0D }) { continue }
      if let record = try? decoder.decode(SpoolRecord.self, from: line) {
        records.append(record)
      } else {
        skipped += 1
      }
    }
    return Parsed(records: records, remainder: Data(bytes[lineStart...]), skipped: skipped)
  }
}
